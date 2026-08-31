import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/db_helper.dart';
import '../../data/models/item_model.dart';
import '../../data/models/transfer_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../data/models/return_invoice_model.dart';
import '../../data/models/customer_model.dart';
import '../../core/services/unit_conversion_engine.dart';

class InventoryProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<TransferModel> _transfers = [];
  TransferModel? _selectedTransfer;
  List<ItemModel> _localItems = [];
  List<ReturnInvoiceModel> _returns = [];
  bool _isLoading = false;
  String _searchQuery = '';

  DBHelper get dbHelper => _dbHelper;
  List<TransferModel> get transfers => _transfers;
  TransferModel? get selectedTransfer => _selectedTransfer;
  List<ItemModel> get localItems => _localItems;
  List<ReturnInvoiceModel> get returns => _returns;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  List<TransferItemModel> get filteredTransferItems {
    if (_selectedTransfer == null) return [];
    if (_searchQuery.trim().isEmpty) return _selectedTransfer!.items;

    final query = _searchQuery.trim().toLowerCase();
    return _selectedTransfer!.items.where((item) {
      return item.itemCode.toLowerCase().contains(query) ||
          item.itemName.toLowerCase().contains(query) ||
          item.author.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> loadTransfers() async {
    _isLoading = true;
    notifyListeners();

    _transfers = await _dbHelper.getTransfers();
    if (_transfers.isNotEmpty && _selectedTransfer == null) {
      _selectedTransfer = _transfers.first;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectTransfer(String id) async {
    _isLoading = true;
    notifyListeners();

    _selectedTransfer = await _dbHelper.getTransferById(id);
    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> updateItemQuantity(int itemId, double newActualQty, {String? notes, String? imagePath}) async {
    if (_selectedTransfer == null) return;

    final index = _selectedTransfer!.items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _selectedTransfer!.items[index].actualQty = newActualQty;
      if (notes != null) {
        _selectedTransfer!.items[index].notes = notes;
      }
      if (imagePath != null) {
        _selectedTransfer!.items[index].imagePath = imagePath;
      }

      await _dbHelper.updateTransferItemQty(itemId, newActualQty, notes, imagePath: imagePath);
      notifyListeners();
    }
  }

  Future<void> confirmSelectedTransferAudit() async {
    if (_selectedTransfer == null) return;

    bool hasDiscrepancy = _selectedTransfer!.items.any((item) => item.hasDiscrepancy);
    String newStatus = hasDiscrepancy ? 'audited_discrepancy' : 'audited_matched';

    await _dbHelper.confirmTransferAudit(_selectedTransfer!.id, newStatus);
    _selectedTransfer!.status = newStatus;

    await loadTransfers();
    await loadLocalItems();
  }

  Future<void> loadLocalItems() async {
    _localItems = await _dbHelper.getLocalItems();
    notifyListeners();
  }

  Future<void> registerNewScannedItem({
    required String barcode,
    required String itemName,
    required String category,
    required String unit,
    required double initialQty,
    double defaultPrice = 25.0,
    String location = 'ممر A - رف 1 - كابينة 1',
  }) async {
    await _dbHelper.registerOrUpdateLocalItem(
      code: barcode,
      name: itemName,
      category: category,
      unit: unit,
      initialQty: initialQty,
      unitPrice: defaultPrice,
      location: location,
    );

    if (_selectedTransfer != null) {
      final db = await _dbHelper.database;
      if (db != null) {
        await db.insert('transfer_items', {
          'transfer_id': _selectedTransfer!.id,
          'item_code': barcode,
          'item_name': itemName,
          'author': _selectedTransfer!.author,
          'expected_qty': initialQty,
          'actual_qty': initialQty,
          'notes': 'صنف جديد مضاف عبر المسح الضوئي (Barcode: $barcode)',
        });
        await selectTransfer(_selectedTransfer!.id);
      }
    }

    await loadLocalItems();
  }

  Future<void> recordPeriodicAudit(String itemCode, String itemName, double systemQty, double countedQty, String? notes) async {
    await _dbHelper.recordLocalStockAudit(itemCode, itemName, systemQty, countedQty, notes);
    await loadLocalItems();
  }

  Future<String> createTransferInvoice({
    required String transferNumber,
    required String fromWarehouse,
    required String toWarehouse,
    required String author,
    required String notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final transferId = await _dbHelper.createNewCustomTransfer(
      transferNumber: transferNumber,
      fromWarehouse: fromWarehouse,
      toWarehouse: toWarehouse,
      author: author,
      notes: notes,
      items: items,
    );
    await loadTransfers();
    await selectTransfer(transferId);
    return transferId;
  }

  Future<void> adjustItemStockDirectly(String itemCode, double newStock, String reasonNote) async {
    await _dbHelper.updateItemStockDirectly(itemCode, newStock, reasonNote);
    await loadLocalItems();
  }

  Future<void> addItem(ItemModel item) async {
    final db = await _dbHelper.database;
    if (db != null) {
      await db.insert('items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await loadLocalItems();
  }

  Future<void> updateItemStock(String itemCode, double newStock) async {
    await adjustItemStockDirectly(itemCode, newStock, 'تحديث رصيد عبر المسح الضوئي الذكي (AI OCR)');
  }

  Future<void> updateInvoiceNotes(String transferId, String newNotes) async {
    final db = await _dbHelper.database;
    if (db != null) {
      await db.update(
        'transfers',
        {'notes': newNotes},
        where: 'id = ?',
        whereArgs: [transferId],
      );
    }
    if (_selectedTransfer != null && _selectedTransfer!.id == transferId) {
      _selectedTransfer = TransferModel(
        id: _selectedTransfer!.id,
        transferNumber: _selectedTransfer!.transferNumber,
        fromWarehouse: _selectedTransfer!.fromWarehouse,
        toWarehouse: _selectedTransfer!.toWarehouse,
        author: _selectedTransfer!.author,
        date: _selectedTransfer!.date,
        status: _selectedTransfer!.status,
        notes: newNotes,
        items: _selectedTransfer!.items,
      );
      notifyListeners();
    }
    await loadTransfers();
  }

  Future<void> updateItemLocation(String itemCode, String newLocation) async {
    final db = await _dbHelper.database;
    if (db != null) {
      await db.update(
        'items',
        {'location': newLocation},
        where: 'code = ?',
        whereArgs: [itemCode],
      );
    }
    await loadLocalItems();
  }

  Future<void> addOrUpdateProductUnit(ProductUnitModel unit) async {
    await _dbHelper.saveProductUnit(unit);
    await loadLocalItems();
  }

  Future<void> recordHybridPeriodicAudit({
    required ItemModel item,
    required List<UnitQuantityInput> inputs,
    String? notes,
  }) async {
    final countedBaseQty = UnitConversionEngine.calculateHybridQuantity(item: item, inputs: inputs);
    await _dbHelper.recordLocalStockAudit(item.code, item.name, item.currentStock, countedBaseQty, notes);

    final snapshot = UnitConversionEngine.createHistoricalSnapshot(
      transactionId: 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
      transactionType: 'AUDIT',
      item: item,
      enteredUnit: inputs.first.unitName,
      enteredQuantity: inputs.first.quantity,
      notes: 'جرد دوري مركب (${inputs.length} وحدات): $notes',
    );
    await _dbHelper.postStockMovement(snapshot);
    await loadLocalItems();
  }

  Future<void> loadReturns() async {
    final rawReturns = await _dbHelper.getReturnInvoices();
    List<ReturnInvoiceModel> loaded = [];
    for (var r in rawReturns) {
      final rawItems = await _dbHelper.getReturnItems(r['id']);
      final items = rawItems.map((i) => ReturnItemModel.fromMap(i)).toList();
      loaded.add(ReturnInvoiceModel.fromMap(r, items));
    }
    _returns = loaded;
    notifyListeners();
  }

  Future<void> processReturnInvoice({
    required ReturnType returnType,
    required String partyName,
    required String refundMethod,
    required String notes,
    required List<ReturnItemModel> items,
  }) async {
    final id = 'RET-${DateTime.now().millisecondsSinceEpoch}';
    final returnNumber = returnType == ReturnType.salesReturn
        ? 'RET-SALE-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
        : 'RET-SUPP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final date = DateTime.now().toString().split(' ').first;

    final totalAmount = items.fold(0.0, (sum, i) => sum + i.totalPrice);

    final itemMaps = items.map((i) => i.toMap(id)).toList();

    await _dbHelper.createReturnInvoice(
      id: id,
      returnNumber: returnNumber,
      returnType: returnType == ReturnType.salesReturn ? 'sales' : 'purchase',
      partyName: partyName,
      date: date,
      refundMethod: refundMethod,
      notes: notes,
      totalAmount: totalAmount,
      items: itemMaps,
    );

    // Record Stock Movement Snapshot per returned item
    for (var item in items) {
      final localItem = _localItems.firstWhere((i) => i.code == item.itemCode, orElse: () => ItemModel(code: item.itemCode, name: item.itemName, category: 'عام', legacyUnit: item.unit, currentStock: 0, unitPrice: item.unitPrice));
      final snapshot = UnitConversionEngine.createHistoricalSnapshot(
        transactionId: id,
        transactionType: returnType == ReturnType.salesReturn ? 'SALES_RETURN' : 'PURCHASE_RETURN',
        item: localItem,
        enteredUnit: item.unit,
        enteredQuantity: item.returnedQty,
        notes: '${returnType == ReturnType.salesReturn ? "مرتجع مبيعات عميل" : "مرتجع توريد مورد"} - ${item.reason}',
      );
      await _dbHelper.postStockMovement(snapshot);
    }

    await loadLocalItems();
    await loadReturns();
  }

  Future<void> clearAllDataAndReset() async {
    _isLoading = true;
    notifyListeners();

    await _dbHelper.clearAllDatabaseData();

    _localItems.clear();
    _transfers.clear();
    _selectedTransfer = null;
    _returns.clear();
    CustomerModel.clearAllCustomers();

    _isLoading = false;
    notifyListeners();
  }
}
