import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/item_model.dart';
import '../../data/models/transfer_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../core/services/unit_conversion_engine.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;
  bool _isInMemoryFallback = false;

  // In-memory fallback structures for web/testing or SQLite failures
  final List<Map<String, dynamic>> _memItems = [];
  final List<Map<String, dynamic>> _memTransfers = [];
  final List<Map<String, dynamic>> _memTransferItems = [];
  final List<Map<String, dynamic>> _memSales = [];
  final List<Map<String, dynamic>> _memSaleItems = [];
  final List<Map<String, dynamic>> _memProductUnits = [];
  final List<Map<String, dynamic>> _memStockMovements = [];
  final List<Map<String, dynamic>> _memReturns = [];
  final List<Map<String, dynamic>> _memReturnItems = [];
  final List<Map<String, dynamic>> _memCustomers = [];
  final List<Map<String, dynamic>> _memCustomerPayments = [];

  Future<Database?> get database async {
    if (kIsWeb) {
      _isInMemoryFallback = true;
      return null;
    }
    if (_database != null) return _database!;
    try {
      _database = await _initDB();
      return _database!;
    } catch (e) {
      debugPrint("Native SQLite failed or running on web fallback: $e");
      _isInMemoryFallback = true;
      return null;
    }
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'benaa_inventory.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE items ADD COLUMN unit_price REAL DEFAULT 25.0;'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN location TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN size TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN color TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN finish_type TEXT;'); } catch (_) {}
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        unit TEXT,
        packaging_unit TEXT,
        conversion_factor REAL DEFAULT 1.0,
        current_stock REAL DEFAULT 0.0,
        unit_price REAL DEFAULT 25.0,
        location TEXT,
        size TEXT,
        color TEXT,
        finish_type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transfers (
        id TEXT PRIMARY KEY,
        transfer_number TEXT NOT NULL,
        from_warehouse TEXT NOT NULL,
        to_warehouse TEXT NOT NULL,
        author TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transfer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id TEXT NOT NULL,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        author TEXT NOT NULL,
        expected_qty REAL NOT NULL,
        actual_qty REAL NOT NULL,
        notes TEXT,
        image_path TEXT,
        FOREIGN KEY (transfer_id) REFERENCES transfers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audit_number TEXT NOT NULL,
        audit_date TEXT NOT NULL,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        system_qty REAL NOT NULL,
        counted_qty REAL NOT NULL,
        variance REAL NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL,
        shop_name TEXT NOT NULL,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id TEXT NOT NULL,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        qty REAL NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE product_units (
        id TEXT PRIMARY KEY,
        product_code TEXT NOT NULL,
        unit_name TEXT NOT NULL,
        unit_type TEXT NOT NULL,
        conversion_factor REAL NOT NULL,
        is_base INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        sale_price REAL,
        purchase_price REAL,
        FOREIGN KEY (product_code) REFERENCES items (code) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        transaction_type TEXT NOT NULL,
        product_code TEXT NOT NULL,
        entered_quantity REAL NOT NULL,
        entered_unit TEXT NOT NULL,
        conversion_factor REAL NOT NULL,
        base_quantity REAL NOT NULL,
        base_unit TEXT NOT NULL,
        created_at TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE returns (
        id TEXT PRIMARY KEY,
        return_number TEXT NOT NULL,
        return_type TEXT NOT NULL,
        party_name TEXT NOT NULL,
        date TEXT NOT NULL,
        refund_method TEXT NOT NULL,
        notes TEXT,
        total_amount REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id TEXT NOT NULL,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        returned_qty REAL NOT NULL,
        unit TEXT NOT NULL,
        base_qty REAL NOT NULL,
        unit_price REAL NOT NULL,
        reason TEXT,
        FOREIGN KEY (return_id) REFERENCES returns (id) ON DELETE CASCADE
      )
    ''');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    // Production Mode: Clean Empty Initial State
  }

  // --- Web / Fallback In-Memory Initializer ---
  void _initMemData() {
    // Production Mode: Clean Empty Initial State
  }

  // --- CRUD Operations ---

  Future<List<TransferModel>> getTransfers() async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      List<TransferModel> result = [];
      for (var map in _memTransfers) {
        final tId = map['id'].toString();
        final itemsMap = _memTransferItems.where((i) => i['transfer_id'] == tId).toList();
        final items = itemsMap.map((i) => TransferItemModel.fromMap(i)).toList();
        result.add(TransferModel.fromMap(map, items: items));
      }
      return result;
    }

    try {
      var transferMaps = await db.query('transfers');
      List<TransferModel> transfers = [];
      for (var map in transferMaps) {
        final transferId = map['id'].toString();
        final itemMaps = await db.query(
          'transfer_items',
          where: 'transfer_id = ?',
          whereArgs: [transferId],
        );
        final items = itemMaps.map((i) => TransferItemModel.fromMap(i)).toList();
        transfers.add(TransferModel.fromMap(map, items: items));
      }
      return transfers;
    } catch (e) {
      debugPrint("Error fetching transfers from SQLite: $e");
      _isInMemoryFallback = true;
      return getTransfers();
    }
  }

  Future<TransferModel?> getTransferById(String id) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      final maps = _memTransfers.where((t) => t['id'] == id).toList();
      if (maps.isEmpty) return null;
      final itemsMap = _memTransferItems.where((i) => i['transfer_id'] == id).toList();
      final items = itemsMap.map((i) => TransferItemModel.fromMap(i)).toList();
      return TransferModel.fromMap(maps.first, items: items);
    }

    try {
      final maps = await db.query('transfers', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;

      final itemMaps = await db.query('transfer_items', where: 'transfer_id = ?', whereArgs: [id]);
      final items = itemMaps.map((i) => TransferItemModel.fromMap(i)).toList();
      return TransferModel.fromMap(maps.first, items: items);
    } catch (e) {
      debugPrint("Error fetching transfer by id from SQLite: $e");
      _isInMemoryFallback = true;
      return getTransferById(id);
    }
  }

  Future<void> updateTransferItemQty(int itemId, double actualQty, String? notes, {String? imagePath}) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      final idx = _memTransferItems.indexWhere((i) => i['id'] == itemId);
      if (idx != -1) {
        _memTransferItems[idx]['actual_qty'] = actualQty;
        _memTransferItems[idx]['notes'] = notes;
        if (imagePath != null) {
          _memTransferItems[idx]['image_path'] = imagePath;
        }
      }
      return;
    }

    try {
      Map<String, dynamic> updateData = {'actual_qty': actualQty, 'notes': notes};
      if (imagePath != null) {
        updateData['image_path'] = imagePath;
      }
      await db.update(
        'transfer_items',
        updateData,
        where: 'id = ?',
        whereArgs: [itemId],
      );
    } catch (e) {
      debugPrint("Error updating transfer item qty: $e");
    }
  }

  Future<void> confirmTransferAudit(String transferId, String status) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      final idx = _memTransfers.indexWhere((t) => t['id'] == transferId);
      if (idx != -1) {
        final currentStatus = (_memTransfers[idx]['status'] ?? '').toString();
        // IDEMPOTENCY PROTECTION: Prevent duplicate stock addition on rapid double taps
        if (currentStatus.startsWith('audited')) {
          _memTransfers[idx]['status'] = status;
          return;
        }
        _memTransfers[idx]['status'] = status;
      }
      final itemsForTransfer = _memTransferItems.where((i) => i['transfer_id'] == transferId).toList();
      for (var tItem in itemsForTransfer) {
        final code = (tItem['item_code'] ?? '').toString().trim();
        final name = (tItem['item_name'] ?? '').toString().trim();
        final actualQty = (tItem['actual_qty'] as num).toDouble();

        final itemIdx = _memItems.indexWhere((i) {
          final c = (i['code'] ?? '').toString().trim().toLowerCase();
          final n = (i['name'] ?? '').toString().trim().toLowerCase();
          return (code.isNotEmpty && c == code.toLowerCase()) ||
              (name.isNotEmpty && n == name.toLowerCase());
        });

        if (itemIdx != -1) {
          final oldStock = (_memItems[itemIdx]['current_stock'] as num).toDouble();
          _memItems[itemIdx]['current_stock'] = oldStock + actualQty;
        } else {
          _memItems.add({
            'code': code.isNotEmpty ? code : 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}',
            'name': name.isNotEmpty ? name : 'صنف جديد',
            'category': 'عام',
            'unit': 'حبة',
            'packaging_unit': 'كرتونة',
            'conversion_factor': 1.0,
            'current_stock': actualQty,
            'unit_price': 25.0,
            'location': 'ممر A - رف 1',
          });
        }
      }
      return;
    }

    try {
      final existingTransfer = await db.query('transfers', where: 'id = ?', whereArgs: [transferId]);
      if (existingTransfer.isNotEmpty) {
        final currentStatus = (existingTransfer.first['status'] ?? '').toString();
        if (currentStatus.startsWith('audited')) {
          await db.update('transfers', {'status': status}, where: 'id = ?', whereArgs: [transferId]);
          return; // Already audited, do not double-add stock
        }
      }

      await db.update(
        'transfers',
        {'status': status},
        where: 'id = ?',
        whereArgs: [transferId],
      );

      final itemMaps = await db.query('transfer_items', where: 'transfer_id = ?', whereArgs: [transferId]);
      for (var map in itemMaps) {
        final itemCode = (map['item_code'] ?? '').toString().trim();
        final itemName = (map['item_name'] ?? '').toString().trim();
        final actualQty = (map['actual_qty'] as num).toDouble();

        final existing = await db.query(
          'items',
          where: 'code = ? OR LOWER(TRIM(name)) = ?',
          whereArgs: [itemCode, itemName.toLowerCase()],
        );

        if (existing.isNotEmpty) {
          final existingCode = existing.first['code'].toString();
          await db.rawUpdate('''
            UPDATE items 
            SET current_stock = current_stock + ? 
            WHERE code = ?
          ''', [actualQty, existingCode]);
        } else {
          await db.insert(
            'items',
            {
              'code': itemCode.isNotEmpty ? itemCode : 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}',
              'name': itemName.isNotEmpty ? itemName : 'صنف جديد',
              'category': 'عام',
              'unit': 'حبة',
              'packaging_unit': 'كرتونة',
              'conversion_factor': 1.0,
              'current_stock': actualQty,
              'unit_price': 25.0,
              'location': 'ممر A - رف 1',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    } catch (e) {
      debugPrint("Error confirming transfer audit in SQLite: $e");
    }
  }

  Future<List<ItemModel>> getLocalItems() async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      List<ItemModel> result = [];
      for (var map in _memItems) {
        final code = map['code'].toString();
        final unitMaps = _memProductUnits.where((u) => u['product_code'] == code).toList();
        final loadedUnits = unitMaps.isNotEmpty
            ? unitMaps.map((u) => ProductUnitModel.fromMap(u)).toList()
            : null;
        result.add(ItemModel.fromMap(map, loadedUnits: loadedUnits));
      }
      return result;
    }

    try {
      final maps = await db.query('items');
      List<ItemModel> result = [];
      for (var map in maps) {
        final code = map['code'].toString();
        final unitMaps = await db.query('product_units', where: 'product_code = ?', whereArgs: [code]);
        final loadedUnits = unitMaps.isNotEmpty
            ? unitMaps.map((u) => ProductUnitModel.fromMap(u)).toList()
            : null;
        result.add(ItemModel.fromMap(map, loadedUnits: loadedUnits));
      }
      return result;
    } catch (e) {
      debugPrint("Error fetching local items from SQLite: $e");
      _isInMemoryFallback = true;
      return getLocalItems();
    }
  }

  Future<List<ProductUnitModel>> getProductUnits(String productCode) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      final maps = _memProductUnits.where((u) => u['product_code'] == productCode).toList();
      if (maps.isNotEmpty) {
        return maps.map((m) => ProductUnitModel.fromMap(m)).toList();
      }
      final itemMap = _memItems.firstWhere((i) => i['code'] == productCode, orElse: () => {});
      if (itemMap.isNotEmpty) {
        final item = ItemModel.fromMap(itemMap);
        return item.units;
      }
      return [];
    }

    try {
      final maps = await db.query(
        'product_units',
        where: 'product_code = ?',
        whereArgs: [productCode],
      );

      if (maps.isNotEmpty) {
        return maps.map((m) => ProductUnitModel.fromMap(m)).toList();
      }

      final itemMaps = await db.query('items', where: 'code = ?', whereArgs: [productCode]);
      if (itemMaps.isNotEmpty) {
        final item = ItemModel.fromMap(itemMaps.first);
        return item.units;
      }
      return [];
    } catch (e) {
      debugPrint("Error getting product units from SQLite: $e");
      return [];
    }
  }

  Future<void> saveProductUnit(ProductUnitModel unit) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      final idx = _memProductUnits.indexWhere((u) => u['id'] == unit.id);
      if (idx != -1) {
        _memProductUnits[idx] = unit.toMap();
      } else {
        _memProductUnits.add(unit.toMap());
      }
      return;
    }

    try {
      await db.insert(
        'product_units',
        unit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint("Error saving product unit to SQLite: $e");
    }
  }

  Future<void> postStockMovement(StockMovementSnapshot snapshot) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      _memStockMovements.add(snapshot.toMap());
      return;
    }

    try {
      await db.insert('stock_movements', snapshot.toMap());
    } catch (e) {
      debugPrint("Error posting stock movement to SQLite: $e");
    }
  }

  Future<List<StockMovementSnapshot>> getStockMovements(String productCode) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      final list = _memStockMovements.where((m) => m['product_code'] == productCode).toList();
      return list.map((m) => StockMovementSnapshot(
        transactionId: m['id'],
        transactionType: m['transaction_type'],
        productCode: m['product_code'],
        enteredQuantity: (m['entered_quantity'] as num).toDouble(),
        enteredUnit: m['entered_unit'],
        conversionFactor: (m['conversion_factor'] as num).toDouble(),
        baseQuantity: (m['base_quantity'] as num).toDouble(),
        baseUnit: m['base_unit'],
        date: m['created_at'],
        notes: m['notes'],
      )).toList();
    }

    try {
      final maps = await db.query(
        'stock_movements',
        where: 'product_code = ?',
        whereArgs: [productCode],
        orderBy: 'created_at DESC',
      );

      return maps.map((m) => StockMovementSnapshot(
        transactionId: m['id'].toString(),
        transactionType: m['transaction_type'].toString(),
        productCode: m['product_code'].toString(),
        enteredQuantity: (m['entered_quantity'] as num).toDouble(),
        enteredUnit: m['entered_unit'].toString(),
        conversionFactor: (m['conversion_factor'] as num).toDouble(),
        baseQuantity: (m['base_quantity'] as num).toDouble(),
        baseUnit: m['base_unit'].toString(),
        date: m['created_at'].toString(),
        notes: m['notes']?.toString(),
      )).toList();
    } catch (e) {
      debugPrint("Error getting stock movements from SQLite: $e");
      return [];
    }
  }

  Future<void> recordLocalStockAudit(String itemCode, String itemName, double systemQty, double countedQty, String? notes) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      final idx = _memItems.indexWhere((i) => i['code'] == itemCode);
      if (idx != -1) {
        _memItems[idx]['current_stock'] = countedQty;
      }
      return;
    }

    try {
      await db.update(
        'items',
        {'current_stock': countedQty},
        where: 'code = ?',
        whereArgs: [itemCode],
      );
    } catch (e) {
      debugPrint("Error recording local stock audit in SQLite: $e");
    }
  }

  static int _txCounter = 1;

  Future<String> createNewCustomTransfer({
    required String transferNumber,
    required String fromWarehouse,
    required String toWarehouse,
    required String author,
    required String notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final transferId = 'trf-custom-${DateTime.now().microsecondsSinceEpoch}-${_txCounter++}';
    final db = await database;

    if (db == null || _isInMemoryFallback) {
      _memTransfers.add({
        'id': transferId,
        'transfer_number': transferNumber,
        'from_warehouse': fromWarehouse,
        'to_warehouse': toWarehouse,
        'author': author,
        'date': DateTime.now().toIso8601String().split('T').first,
        'status': 'pending_audit',
        'notes': notes,
      });

      int nextId = _memTransferItems.isEmpty ? 1 : ((_memTransferItems.map((i) => i['id'] is int ? i['id'] as int : 0).fold(0, (max, e) => e > max ? e : max)) + 1);
      for (var item in items) {
        final qty = (item['qty'] ?? item['expected_qty'] as num?)?.toDouble() ?? 1.0;
        _memTransferItems.add({
          'id': nextId++,
          'transfer_id': transferId,
          'item_code': item['item_code'],
          'item_name': item['item_name'],
          'author': author,
          'expected_qty': qty,
          'actual_qty': qty,
          'notes': item['notes'] ?? '',
        });
      }
      return transferId;
    }

    try {
      await db.insert(
        'transfers',
        {
          'id': transferId,
          'transfer_number': transferNumber,
          'from_warehouse': fromWarehouse,
          'to_warehouse': toWarehouse,
          'author': author,
          'date': DateTime.now().toIso8601String().split('T').first,
          'status': 'pending_audit',
          'notes': notes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (var item in items) {
        await db.insert(
          'transfer_items',
          {
            'transfer_id': transferId,
            'item_code': item['item_code'],
            'item_name': item['item_name'],
            'author': author,
            'expected_qty': (item['qty'] as num).toDouble(),
            'actual_qty': (item['qty'] as num).toDouble(),
            'notes': item['notes'] ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint("Error inserting transfer into SQLite: $e. Using fallback.");
      _isInMemoryFallback = true;
      return createNewCustomTransfer(
        transferNumber: transferNumber,
        fromWarehouse: fromWarehouse,
        toWarehouse: toWarehouse,
        author: author,
        notes: notes,
        items: items,
      );
    }

    return transferId;
  }

  Future<void> registerOrUpdateLocalItem({
    required String code,
    required String name,
    required String category,
    required String unit,
    required double initialQty,
    double unitPrice = 25.0,
    String location = 'ممر A - رف 1 - كابينة 1',
  }) async {
    final cleanCode = code.trim();
    final cleanName = name.trim();

    final db = await database;
    if (db == null || _isInMemoryFallback) {
      final idx = _memItems.indexWhere((i) {
        final c = (i['code'] ?? '').toString().trim().toLowerCase();
        final n = (i['name'] ?? '').toString().trim().toLowerCase();
        return (cleanCode.isNotEmpty && c == cleanCode.toLowerCase()) ||
            (cleanName.isNotEmpty && n == cleanName.toLowerCase());
      });

      if (idx != -1) {
        final current = (_memItems[idx]['current_stock'] as num).toDouble();
        _memItems[idx]['current_stock'] = current + initialQty;
        _memItems[idx]['name'] = cleanName;
        _memItems[idx]['unit'] = unit;
        _memItems[idx]['category'] = category;
        _memItems[idx]['location'] = location;
      } else {
        _memItems.add({
          'code': cleanCode.isNotEmpty ? cleanCode : 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}',
          'name': cleanName,
          'category': category,
          'unit': unit,
          'packaging_unit': 'كرتونة',
          'conversion_factor': 1.0,
          'current_stock': initialQty,
          'unit_price': unitPrice,
          'location': location,
        });
      }
      return;
    }

    try {
      final existing = await db.query(
        'items',
        where: 'code = ? OR LOWER(TRIM(name)) = ?',
        whereArgs: [cleanCode, cleanName.toLowerCase()],
      );

      if (existing.isNotEmpty) {
        final existingCode = existing.first['code'].toString();
        final currentStock = (existing.first['current_stock'] as num).toDouble();
        await db.update(
          'items',
          {
            'name': cleanName,
            'category': category,
            'unit': unit,
            'current_stock': currentStock + initialQty,
            'unit_price': unitPrice,
            'location': location,
          },
          where: 'code = ?',
          whereArgs: [existingCode],
        );
      } else {
        await db.insert(
          'items',
          {
            'code': cleanCode.isNotEmpty ? cleanCode : 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}',
            'name': cleanName,
            'category': category,
            'unit': unit,
            'packaging_unit': 'كرتونة',
            'conversion_factor': 1.0,
            'current_stock': initialQty,
            'unit_price': unitPrice,
            'location': location,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint("Error in registerOrUpdateLocalItem SQLite: $e");
    }
  }

  Future<void> updateItemStockDirectly(String itemCode, double newStock, String reasonNote) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      final idx = _memItems.indexWhere((i) => i['code'] == itemCode);
      if (idx != -1) {
        _memItems[idx]['current_stock'] = newStock;
      }
      return;
    }

    try {
      await db.update(
        'items',
        {'current_stock': newStock},
        where: 'code = ?',
        whereArgs: [itemCode],
      );

      await db.insert('audit_logs', {
        'audit_number': 'ADJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'audit_date': DateTime.now().toIso8601String().split('T').first,
        'item_code': itemCode,
        'item_name': 'تعديل مخزون مباشر',
        'system_qty': 0,
        'counted_qty': newStock,
        'variance': 0,
        'notes': reasonNote,
      });
    } catch (e) {
      debugPrint("Error updating item stock directly in SQLite: $e");
    }
  }

  Future<void> createSaleOrder(String id, String invoiceNumber, String shopName, double totalAmount, List<Map<String, dynamic>> items) async {
    final date = DateTime.now().toIso8601String().split('T').first;

    CustomerModel.registerSaleForCustomer(shopName, totalAmount);

    if (_database == null || _isInMemoryFallback) {
      _memSales.add({
        'id': id,
        'invoice_number': invoiceNumber,
        'shop_name': shopName,
        'date': date,
        'total_amount': totalAmount,
        'status': 'completed',
        'items': items,
      });

      for (var item in items) {
        final itemCode = item['item_code'].toString();
        final qty = (item['qty'] as num).toDouble();

        _memSaleItems.add({
          'sale_id': id,
          'item_code': itemCode,
          'item_name': item['item_name'],
          'qty': qty,
          'unit_price': (item['unit_price'] as num).toDouble(),
        });

        final idx = _memItems.indexWhere((i) => i['code'] == itemCode);
        if (idx != -1) {
          final current = (_memItems[idx]['current_stock'] as num).toDouble();
          _memItems[idx]['current_stock'] = (current - qty).clamp(0.0, double.infinity);
        }
      }
      return;
    }

    final db = await database;
    if (db == null) return;

    try {
      await db.insert('sales', {
        'id': id,
        'invoice_number': invoiceNumber,
        'shop_name': shopName,
        'date': date,
        'total_amount': totalAmount,
        'status': 'completed',
      });

      for (var item in items) {
        final itemCode = item['item_code'].toString();
        final qty = (item['qty'] as num).toDouble();

        await db.insert('sale_items', {
          'sale_id': id,
          'item_code': itemCode,
          'item_name': item['item_name'],
          'qty': qty,
          'unit_price': (item['unit_price'] as num).toDouble(),
        });

        await db.rawUpdate('''
          UPDATE items 
          SET current_stock = current_stock - ? 
          WHERE code = ?
        ''', [qty, itemCode]);
      }
    } catch (e) {
      debugPrint("Error creating sale order in SQLite: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getSalesForCustomer(String shopName) async {
    final query = shopName.trim().toLowerCase();
    if (_database == null || _isInMemoryFallback) {
      return _memSales.where((s) {
        final name = (s['shop_name'] as String? ?? '').toLowerCase();
        return name.contains(query) || query.contains(name);
      }).toList();
    }

    final db = await database;
    if (db == null) return [];

    try {
      return await db.query(
        'sales',
        where: 'LOWER(shop_name) LIKE ?',
        whereArgs: ['%$query%'],
      );
    } catch (e) {
      debugPrint("Error getting sales for customer: $e");
      return [];
    }
  }

  Future<void> createReturnInvoice({
    required String id,
    required String returnNumber,
    required String returnType,
    required String partyName,
    required String date,
    required String refundMethod,
    required String notes,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _memReturns.add({
        'id': id,
        'return_number': returnNumber,
        'return_type': returnType,
        'party_name': partyName,
        'date': date,
        'refund_method': refundMethod,
        'notes': notes,
        'total_amount': totalAmount,
      });

      for (var item in items) {
        final itemCode = item['item_code'].toString();
        final baseQty = (item['base_qty'] as num).toDouble();

        _memReturnItems.add({
          'return_id': id,
          'item_code': itemCode,
          'item_name': item['item_name'],
          'returned_qty': (item['returned_qty'] as num).toDouble(),
          'unit': item['unit'],
          'base_qty': baseQty,
          'unit_price': (item['unit_price'] as num).toDouble(),
          'reason': item['reason'],
        });

        final existingItemIndex = _memItems.indexWhere((i) => i['code'] == itemCode);
        if (existingItemIndex != -1) {
          final currentStock = (_memItems[existingItemIndex]['current_stock'] as num).toDouble();
          final newStock = returnType == 'sales' ? currentStock + baseQty : currentStock - baseQty;
          _memItems[existingItemIndex]['current_stock'] = newStock > 0 ? newStock : 0.0;
        }
      }
      return;
    }

    try {
      await db.insert('returns', {
        'id': id,
        'return_number': returnNumber,
        'return_type': returnType,
        'party_name': partyName,
        'date': date,
        'refund_method': refundMethod,
        'notes': notes,
        'total_amount': totalAmount,
      });

      for (var item in items) {
        final itemCode = item['item_code'].toString();
        final baseQty = (item['base_qty'] as num).toDouble();

        await db.insert('return_items', {
          'return_id': id,
          'item_code': itemCode,
          'item_name': item['item_name'],
          'returned_qty': (item['returned_qty'] as num).toDouble(),
          'unit': item['unit'],
          'base_qty': baseQty,
          'unit_price': (item['unit_price'] as num).toDouble(),
          'reason': item['reason'],
        });

        if (returnType == 'sales') {
          await db.rawUpdate('''
            UPDATE items 
            SET current_stock = current_stock + ? 
            WHERE code = ?
          ''', [baseQty, itemCode]);
        } else {
          await db.rawUpdate('''
            UPDATE items 
            SET current_stock = CASE WHEN current_stock >= ? THEN current_stock - ? ELSE 0 END 
            WHERE code = ?
          ''', [baseQty, baseQty, itemCode]);
        }
      }
    } catch (e) {
      debugPrint("Error creating return invoice in SQLite: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getReturnInvoices() async {
    if (_database == null || _isInMemoryFallback) {
      return List.from(_memReturns);
    }
    final db = await database;
    if (db == null) return [];
    try {
      return await db.query('returns', orderBy: 'date DESC');
    } catch (e) {
      debugPrint("Error getting return invoices: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReturnItems(String returnId) async {
    if (_database == null || _isInMemoryFallback) {
      return _memReturnItems.where((i) => i['return_id'] == returnId).toList();
    }
    final db = await database;
    if (db == null) return [];
    try {
      return await db.query('return_items', where: 'return_id = ?', whereArgs: [returnId]);
    } catch (e) {
      debugPrint("Error getting return items: $e");
      return [];
    }
  }

  Future<void> clearAllDatabaseData() async {
    final db = await database;
    if (db != null) {
      try { await db.delete('items'); } catch (_) {}
      try { await db.delete('transfers'); } catch (_) {}
      try { await db.delete('transfer_items'); } catch (_) {}
      try { await db.delete('audit_logs'); } catch (_) {}
      try { await db.delete('product_units'); } catch (_) {}
      try { await db.delete('stock_movements'); } catch (_) {}
      try { await db.delete('returns'); } catch (_) {}
      try { await db.delete('return_items'); } catch (_) {}
    }

    _memItems.clear();
    _memTransfers.clear();
    _memTransferItems.clear();
    _memSales.clear();
    _memSaleItems.clear();
    _memProductUnits.clear();
    _memStockMovements.clear();
    _memReturns.clear();
    _memReturnItems.clear();
  }

  /// Get Database raw bytes for backup/export
  Future<Uint8List?> getDatabaseBytes() async {
    try {
      if (kIsWeb) return null;
      String path = join(await getDatabasesPath(), 'benaa_inventory.db');
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint("Failed to read database bytes: $e");
    }
    return null;
  }

  /// Delete item from local stock
  Future<void> deleteItem(String code) async {
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _memItems.removeWhere((i) => i['code'] == code);
      return;
    }
    try {
      await db.delete('items', where: 'code = ?', whereArgs: [code]);
      await db.delete('product_units', where: 'product_code = ?', whereArgs: [code]);
    } catch (e) {
      debugPrint("Error deleting item $code: $e");
    }
  }

  /// Safe Void / Cancellation of a Sale Invoice:
  /// 1. Restores sold quantities back to item stock
  /// 2. Reduces customer debt balance
  /// 3. Deletes the invoice
  Future<bool> voidSaleInvoice(int saleId) async {
    if (_database == null || _isInMemoryFallback) {
      final saleIndex = _memSales.indexWhere((s) => s['id'] == saleId);
      if (saleIndex == -1) return false;
      final sale = _memSales[saleIndex];
      final shopName = sale['shop_name'];
      final totalAmount = (sale['total_amount'] as num).toDouble();

      // Restore items stock
      final items = _memSaleItems.where((i) => i['sale_id'] == saleId).toList();
      for (var it in items) {
        final itmIdx = _memItems.indexWhere((m) => m['code'] == it['item_code']);
        if (itmIdx != -1) {
          _memItems[itmIdx]['current_stock'] = (_memItems[itmIdx]['current_stock'] as num).toDouble() + (it['qty'] as num).toDouble();
        }
      }

      // Revert customer balance
      final custIdx = _memCustomers.indexWhere((c) => c['name'] == shopName);
      if (custIdx != -1) {
        final curBal = (_memCustomers[custIdx]['current_balance'] as num).toDouble();
        _memCustomers[custIdx]['current_balance'] = (curBal - totalAmount).clamp(0.0, double.infinity);
      }

      _memSaleItems.removeWhere((i) => i['sale_id'] == saleId);
      _memSales.removeAt(saleIndex);
      return true;
    }

    final db = await database;
    if (db == null) return false;

    try {
      final saleMaps = await db.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (saleMaps.isEmpty) return false;

      final sale = saleMaps.first;
      final shopName = sale['shop_name'].toString();
      final totalAmount = (sale['total_amount'] as num).toDouble();

      // Get sale items
      final saleItems = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);

      // 1. Restock each item
      for (var it in saleItems) {
        final itemCode = it['item_code'].toString();
        final qty = (it['qty'] as num).toDouble();
        await db.rawUpdate('''
          UPDATE items 
          SET current_stock = current_stock + ? 
          WHERE code = ?
        ''', [qty, itemCode]);
      }

      // 2. Adjust customer balance
      await db.rawUpdate('''
        UPDATE customers 
        SET current_balance = MAX(0.0, current_balance - ?) 
        WHERE name = ?
      ''', [totalAmount, shopName]);

      // 3. Delete sale items and sale invoice
      await db.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await db.delete('sales', where: 'id = ?', whereArgs: [saleId]);

      return true;
    } catch (e) {
      debugPrint("Error voiding sale invoice: $e");
      return false;
    }
  }

  /// Safe Void of a Customer Payment:
  /// 1. Re-adds the paid amount back into customer debt
  /// 2. Deletes the payment record
  Future<bool> voidCustomerPayment(int paymentId) async {
    if (_database == null || _isInMemoryFallback) {
      final pIndex = _memCustomerPayments.indexWhere((p) => p['id'] == paymentId);
      if (pIndex == -1) return false;
      final payment = _memCustomerPayments[pIndex];
      final custName = payment['customer_name'];
      final amount = (payment['amount_paid'] as num).toDouble();

      final custIdx = _memCustomers.indexWhere((c) => c['name'] == custName);
      if (custIdx != -1) {
        _memCustomers[custIdx]['current_balance'] = (_memCustomers[custIdx]['current_balance'] as num).toDouble() + amount;
      }
      _memCustomerPayments.removeAt(pIndex);
      return true;
    }

    final db = await database;
    if (db == null) return false;

    try {
      final pMaps = await db.query('customer_payments', where: 'id = ?', whereArgs: [paymentId]);
      if (pMaps.isEmpty) return false;

      final payment = pMaps.first;
      final custName = payment['customer_name'].toString();
      final amount = (payment['amount_paid'] as num).toDouble();

      // Re-add to debt
      await db.rawUpdate('''
        UPDATE customers 
        SET current_balance = current_balance + ? 
        WHERE name = ?
      ''', [amount, custName]);

      await db.delete('customer_payments', where: 'id = ?', whereArgs: [paymentId]);
      return true;
    } catch (e) {
      debugPrint("Error voiding payment: $e");
      return false;
    }
  }

  /// Delete Transfer Voucher
  Future<void> deleteTransfer(String transferId) async {
    if (_database == null || _isInMemoryFallback) {
      _memTransfers.removeWhere((t) => t['id'] == transferId);
      _memTransferItems.removeWhere((i) => i['transfer_id'] == transferId);
      return;
    }

    final db = await database;
    if (db == null) return;

    try {
      await db.delete('transfer_items', where: 'transfer_id = ?', whereArgs: [transferId]);
      await db.delete('transfers', where: 'id = ?', whereArgs: [transferId]);
    } catch (e) {
      debugPrint("Error deleting transfer: $e");
    }
  }
}
