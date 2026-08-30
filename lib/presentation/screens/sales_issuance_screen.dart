import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/item_model.dart';
import '../../data/models/sale_order_model.dart';
import '../providers/inventory_provider.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/bluetooth_printer_service.dart';
import 'package:printing/printing.dart';
import '../../core/services/pdf_report_service.dart';
import '../../data/models/product_unit_model.dart';
import '../../core/services/unit_conversion_engine.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../widgets/nfc_scanner_dialog.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/customer_autocomplete_field.dart';
import '../../core/services/period_archive_filter_service.dart';
import '../widgets/archive_period_selector_bar.dart';

class SalesIssuanceScreen extends StatefulWidget {
  const SalesIssuanceScreen({Key? key}) : super(key: key);

  @override
  State<SalesIssuanceScreen> createState() => _SalesIssuanceScreenState();
}

class _SalesIssuanceScreenState extends State<SalesIssuanceScreen> {
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _invoiceNumController = TextEditingController(
    text: 'INV-BUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
  );
  final TextEditingController _itemSearchController = TextEditingController();
  String _itemSearchQuery = '';
  ArchivePeriodType _archivePeriod = ArchivePeriodType.allTime;
  DateTimeRange? _customDateRange;

  ItemModel? _selectedItem;
  ProductUnitModel? _selectedUnit;
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  List<Map<String, dynamic>> _cartItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadLocalItems();
    });
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _customerPhoneController.dispose();
    _invoiceNumController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addItemToCart() {
    if (_selectedItem == null) return;
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final unitName = _selectedUnit?.unitName ?? _selectedItem!.unit;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال كمية صحيحة أكبر من 0')),
      );
      return;
    }

    final baseQty = UnitConversionEngine.convertToBaseUnit(
      item: _selectedItem!,
      unitName: unitName,
      quantity: qty,
    );

    if (baseQty > _selectedItem!.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('الكمية المطلوبة ($qty $unitName = $baseQty ${_selectedItem!.unit}) أكبر من الرصيد المتاح (${_selectedItem!.currentStock} ${_selectedItem!.unit})'),
        ),
      );
      return;
    }

    HapticsService.scanSuccess();

    setState(() {
      _cartItems.add({
        'item_code': _selectedItem!.code,
        'item_name': _selectedItem!.name,
        'qty': qty,
        'unit': unitName,
        'base_qty': baseQty,
        'unit_price': price,
        'total': qty * price,
      });
      _selectedItem = null;
      _selectedUnit = null;
      _qtyController.clear();
      _priceController.clear();
    });
  }

  void _completeSaleOrder() async {
    if (_shopNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة اسم المحل / العميل')),
      );
      return;
    }

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سلة المبيعات فارغة، أضف صنف واحد على الأقل')),
      );
      return;
    }

    final totalAmount = _cartItems.fold(0.0, (sum, i) => sum + (i['total'] as double));
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    final saleId = 'sale-${DateTime.now().millisecondsSinceEpoch}';
    final invoiceNum = _invoiceNumController.text;
    final shopName = _shopNameController.text.trim();

    // Record sale & deduct stock in local db
    final dbHelper = provider.dbHelper;
    await dbHelper.createSaleOrder(
      saleId,
      invoiceNum,
      shopName,
      totalAmount,
      _cartItems,
    );

    await provider.loadLocalItems();
    await HapticsService.actionSuccess();

    // Auto Print thermal receipt if printer connected
    final connected = await BluetoothPrinterService.isConnected();
    if (connected) {
      final gps = await LocationService.getFormattedLocationString();
      final saleModel = SaleOrderModel(
        id: saleId,
        invoiceNumber: invoiceNum,
        shopName: shopName,
        date: DateTime.now().toString().substring(0, 10),
        totalAmount: totalAmount,
        status: 'completed',
        items: _cartItems
            .map((c) => SaleOrderItemModel(
                  saleId: saleId,
                  itemCode: c['item_code'],
                  itemName: c['item_name'],
                  qty: c['qty'],
                  unitPrice: c['unit_price'],
                ))
            .toList(),
      );
      await BluetoothPrinterService.printSalesIssuanceReceipt(saleModel, gps);
    }

    if (mounted) {
      _showSaleInvoiceOptionsDialog(
        invoiceNum: invoiceNum,
        shopName: shopName,
        customerPhone: _customerPhoneController.text.trim(),
        totalAmount: totalAmount,
        items: List.from(_cartItems),
      );
    }
  }

  void _showSaleInvoiceOptionsDialog({
    required String invoiceNum,
    required String shopName,
    String customerPhone = '',
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) {
    final date = DateTime.now().toString().substring(0, 10);
    final phone = customerPhone.trim().isNotEmpty ? customerPhone.trim() : '0555837753';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 48),
            const SizedBox(height: 8),
            Text(
              'تم إصدار الفاتورة وخصم البضاعة!',
              style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'فاتورة رقم: $invoiceNum | العميل: $shopName',
                style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Option 1: Official VAT Invoice (15% VAT)
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text('🧾 فاتورة مبيعات ضريبية (15% VAT)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('⏳ جاري تجهيز فاتورة المبيعات الضريبية...')),
                    );
                    final pdfBytes = await PdfReportService.generateSaleInvoicePdf(
                      invoiceNumber: invoiceNum,
                      shopName: shopName,
                      customerPhone: phone,
                      date: date,
                      totalAmount: totalAmount,
                      items: items,
                      isVatEnabled: true,
                    );
                    await Printing.layoutPdf(
                      onLayout: (format) async => pdfBytes,
                      name: 'فاتورة_ضريبية_$invoiceNum.pdf',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('⚠️ تنبيه: يرجى السماح بالنوافذ المنبثقة (Pop-ups) بالمتصفح للطباعة ($e)')),
                      );
                    }
                  }
                },
              ),

              const SizedBox(height: 8),

              // Option 2: Invoice without VAT (0% VAT)
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined, color: AppColors.info),
                label: const Text('🧾 فاتورة مبيعات بدون ضريبة (0% VAT)'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.info),
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('⏳ جاري تجهيز الفاتورة بدون ضريبة...')),
                    );
                    final pdfBytes = await PdfReportService.generateSaleInvoicePdf(
                      invoiceNumber: invoiceNum,
                      shopName: shopName,
                      date: date,
                      totalAmount: totalAmount,
                      items: items,
                      isVatEnabled: false,
                    );
                    await Printing.layoutPdf(
                      onLayout: (format) async => pdfBytes,
                      name: 'فاتورة_بدون_ضريبة_$invoiceNum.pdf',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('⚠️ تنبيه: يرجى السماح بالنوافذ المنبثقة (Pop-ups) بالمتصفح ($e)')),
                      );
                    }
                  }
                },
              ),

              const SizedBox(height: 8),

              // Option 3: Goods Delivery Voucher
              ElevatedButton.icon(
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text('📲 إذن تسليم بضاعة (إرسال واتساب)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('⏳ جاري إعداد وتصدير إذن تسليم البضاعة...')),
                    );
                    final pdfBytes = await PdfReportService.generateGoodsDeliveryVoucherPdf(
                      invoiceNumber: invoiceNum,
                      warehouseName: 'مخزن مرحلة',
                      customerName: shopName,
                      customerCode: '320',
                      representative: 'ابراهيم شكرى',
                      date: date,
                      address: 'بريدة',
                      author: 'MOHAMED',
                      time: '04:37:01 ص',
                      notes: 'Note',
                      items: items,
                    );
                    await Printing.sharePdf(
                      bytes: pdfBytes,
                      filename: 'اذن_تسليم_بضاعة_$invoiceNum.pdf',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('⚠️ خطأ في تصدير الفاتورة: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('إغلاق والعودة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBg(context),
      appBar: AppBar(
        title: const Text('إذن صرف / بيع للمحلات'),
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final items = provider.localItems.where((i) => i.currentStock > 0).toList();
          final totalInvoiceAmount = _cartItems.fold(0.0, (sum, i) => sum + (i['total'] as double));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ArchivePeriodSelectorBar(
                  currentPeriod: _archivePeriod,
                  customDateRange: _customDateRange,
                  totalCount: _cartItems.length,
                  totalAmount: totalInvoiceAmount,
                  countLabel: 'أصناف السلة',
                  amountLabel: 'إجمالي الفاتورة الحالية',
                  onPeriodChanged: (selectedType, range) {
                    setState(() {
                      _archivePeriod = selectedType;
                      _customDateRange = range;
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Header Info
                Card(
                  color: AppColors.getCardBg(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.getBorder(context)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CustomerAutocompleteField(
                          controller: _shopNameController,
                          labelText: 'اسم المحل / العميل (ابحث بأول الحروف أو الكود)',
                          onCustomerSelected: (customer) {
                            setState(() {
                              _customerPhoneController.text = customer.phone;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerPhoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: AppColors.getTextPrimary(context)),
                          decoration: InputDecoration(
                            labelText: 'رقم هاتف العميل (اختياري)',
                            hintText: 'مثال: 0555837753',
                            labelStyle: TextStyle(color: AppColors.getTextSecondary(context)),
                            prefixIcon: Icon(Icons.phone_android, color: AppColors.getTextSecondary(context)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _invoiceNumController,
                          style: TextStyle(color: AppColors.getTextPrimary(context)),
                          decoration: InputDecoration(
                            labelText: 'رقم الفاتورة / السند',
                            labelStyle: TextStyle(color: AppColors.getTextSecondary(context)),
                            prefixIcon: Icon(Icons.receipt, color: AppColors.getTextSecondary(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'إضافة أصناف إلى السلة:',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print_outlined, color: AppColors.primaryAccent),
                          tooltip: 'طابعة البلوتوث',
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (ctx) => const PrinterSelectionDialog(),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.nfc, color: AppColors.warning),
                          tooltip: 'شريحة NFC',
                          onPressed: () async {
                            final scannedCode = await showDialog<String>(
                              context: context,
                              builder: (ctx) => const NfcScannerDialog(),
                            );
                            if (scannedCode != null && scannedCode.isNotEmpty) {
                              final itemsList = provider.localItems;
                              final matched = itemsList.where((i) => i.code == scannedCode || i.code.contains(scannedCode));
                              if (matched.isNotEmpty) {
                                setState(() {
                                  _selectedItem = matched.first;
                                  _priceController.text = matched.first.unitPrice.toString();
                                });
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryAccent),
                          tooltip: 'كاميرا الباركود',
                          onPressed: () async {
                            final scannedCode = await showDialog<String>(
                              context: context,
                              builder: (ctx) => const CameraScannerDialog(
                                title: 'مسح باركود الصنف لإضافته للسلة',
                              ),
                            );
                            if (scannedCode != null && scannedCode.isNotEmpty) {
                              final itemsList = provider.localItems;
                              final matched = itemsList.where((i) => i.code == scannedCode || i.code.contains(scannedCode));
                              if (matched.isNotEmpty) {
                                setState(() {
                                  _selectedItem = matched.first;
                                  _priceController.text = matched.first.unitPrice.toString();
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Live Search Bar by Name, Category, or Code
                TextField(
                  controller: _itemSearchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (val) => setState(() => _itemSearchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالأسم، التصنيف، كود الباركود...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryAccent),
                    suffixIcon: _itemSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              _itemSearchController.clear();
                              setState(() => _itemSearchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 8),

                // Filter items based on query
                Builder(
                  builder: (ctx) {
                    final q = _itemSearchQuery.toLowerCase();
                    final filteredItems = _itemSearchQuery.isEmpty
                        ? items
                        : items.where((i) =>
                            i.name.toLowerCase().contains(q) ||
                            i.category.toLowerCase().contains(q) ||
                            i.code.toLowerCase().contains(q)).toList();

                    return DropdownButtonFormField<ItemModel>(
                      value: filteredItems.contains(_selectedItem) ? _selectedItem : null,
                      isExpanded: true,
                      dropdownColor: AppColors.bgCard,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: filteredItems.isEmpty
                            ? 'لا يوجد صنف يطابق البحث'
                            : '-- اختر صنف متوفر في بريدة (${filteredItems.length} صنف) --',
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      items: filteredItems.map((item) {
                        return DropdownMenuItem<ItemModel>(
                          value: item,
                          child: Text(
                            'كود [${item.code}] - ${item.name} | ${item.category} (سعر: ${item.unitPrice} ر.س | المتاح: ${item.currentStock.toInt()})',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedItem = val;
                            _priceController.text = val.unitPrice.toString();
                          });
                        }
                      },
                    );
                  },
                ),

                if (_selectedItem != null) ...[
                  const SizedBox(height: 12),
                  // Multi-Unit Selection
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryAccent.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('اختر وحدة البيع والسعر المطلوب:', style: TextStyle(color: AppColors.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ProductUnitModel>(
                          value: _selectedUnit ?? _selectedItem!.units.firstWhere((u) => u.isBase, orElse: () => _selectedItem!.units.first),
                          dropdownColor: AppColors.bgCard,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'وحدة البيع المتاحة للمنتج',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                          ),
                          items: _selectedItem!.units.where((u) => u.isActive).map((u) {
                            final priceText = u.salePrice != null ? '${u.salePrice} ر.س' : '${(_selectedItem!.unitPrice * u.conversionFactor).toStringAsFixed(2)} ر.س';
                            return DropdownMenuItem<ProductUnitModel>(
                              value: u,
                              child: Text(
                                '${u.unitName} (معامل: ${u.conversionFactor} ${_selectedItem!.unit} | سعر: $priceText)',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (unit) {
                            if (unit != null) {
                              setState(() {
                                _selectedUnit = unit;
                                final calculatedPrice = unit.salePrice ?? (_selectedItem!.unitPrice * unit.conversionFactor);
                                _priceController.text = calculatedPrice.toStringAsFixed(2);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'سعر الوحدة المختارة (ر.س) (اختياري)',
                                  hintText: 'اتركه فارغاً أو 0 إن كان السعر غير محدد',
                                  labelStyle: TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: 'الكمية (${_selectedUnit?.unitName ?? _selectedItem!.unit})',
                                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedUnit != null && !_selectedUnit!.isBase) ...[
                          const SizedBox(height: 6),
                          Text(
                            '💡 1 ${_selectedUnit!.unitName} = ${_selectedUnit!.conversionFactor} ${_selectedItem!.unit}',
                            style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart, color: AppColors.primaryAccent),
                      label: const Text('إضافة الصنف للسلة', style: TextStyle(color: AppColors.primaryAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _addItemToCart,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Cart items table
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text('قائمة الأصناف المباعة:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('الإجمالي: $totalInvoiceAmount ر.س', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),

                const SizedBox(height: 10),

                if (_cartItems.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('لم يتم إضافة أي صنف للسلة بعد', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cartItems.length,
                    itemBuilder: (ctx, idx) {
                      final item = _cartItems[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: AppColors.bgCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.borderDark),
                        ),
                        child: ListTile(
                          title: Text(
                            'كود [${item['item_code']}] - ${item['item_name']}',
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                          subtitle: Text(
                            'الكمية: ${item['qty']} ${item['unit'] ?? ''} ${item['base_qty'] != null && item['base_qty'] != item['qty'] ? '(المكافئ: ${item['base_qty']})' : ''} | سعر الوحدة: ${item['unit_price']} ر.س',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            textAlign: TextAlign.right,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                            onPressed: () {
                              setState(() {
                                _cartItems.removeAt(idx);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('تأكيد إذن الصرف وتحديث المخزون'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: _completeSaleOrder,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
