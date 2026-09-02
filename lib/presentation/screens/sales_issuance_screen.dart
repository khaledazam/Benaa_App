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
import '../../core/services/ceiling_estimation_engine.dart';
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

    double baseQty;
    String? breakdownSummary;

    if (unitName.contains('متر مربع') || unitName.contains('م²')) {
      final result = CeilingEstimationEngine.calculateItemBreakdown(item: _selectedItem!, areaM2: qty);
      baseQty = result.totalPieces;
      breakdownSummary = result.shortSummary;
    } else {
      baseQty = UnitConversionEngine.convertToBaseUnit(
        item: _selectedItem!,
        unitName: unitName,
        quantity: qty,
      );
    }

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
        'breakdown_notes': breakdownSummary,
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

  void _showCeilingProjectEstimatorDialog(BuildContext context, InventoryProvider provider) {
    final areaController = TextEditingController(text: '100');
    final selectedCategories = <CeilingItemCategory>{
      CeilingItemCategory.gypsumTiles,
      CeilingItemCategory.mainTee,
      CeilingItemCategory.wallAngle,
      CeilingItemCategory.crossTee60,
      CeilingItemCategory.crossTee120,
    };

    void addItemToCartDirect(CeilingCalculationResult res, double areaVal) {
      if (areaVal <= 0) return;
      final allItems = provider.localItems;
      final matched = allItems.where((i) {
        final cat = CeilingEstimationEngine.detectCategory(i);
        return cat == res.category;
      }).toList();

      final itemCode = matched.isNotEmpty ? matched.first.code : 'ITEM-${res.category.name}';
      final itemName = matched.isNotEmpty ? matched.first.name : res.itemName;
      final price = matched.isNotEmpty ? matched.first.unitPrice : 25.0;

      _cartItems.add({
        'item_code': itemCode,
        'item_name': itemName,
        'qty': areaVal,
        'unit': 'متر مربع (م²)',
        'base_qty': res.totalPieces,
        'unit_price': price,
        'total': res.totalPieces * price,
        'breakdown_notes': res.shortSummary,
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final area = double.tryParse(areaController.text) ?? 0.0;
          final estimate = CeilingEstimationEngine.calculateFullProject(area > 0 ? area : 0.0);

          return AlertDialog(
            backgroundColor: AppColors.getCardBg(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.architecture, color: AppColors.success, size: 28),
                Text(
                  '📐 مقايسة سقف وديكور (م²)',
                  style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 550,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'أدخل المساحة بالمتر المربع، ثم اختر إضافة بند محدد أو كافة البنود:',
                      style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: areaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 18),
                      textAlign: TextAlign.center,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'المساحة بالمتر المربع (م²)',
                        prefixIcon: Icon(Icons.square_foot, color: AppColors.success),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              if (selectedCategories.length == estimate.allResults.length) {
                                selectedCategories.clear();
                              } else {
                                selectedCategories.addAll(estimate.allResults.map((r) => r.category));
                              }
                            });
                          },
                          child: Text(
                            selectedCategories.length == estimate.allResults.length ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                            style: const TextStyle(color: AppColors.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Text('اختر البنود المراد إضافتها:', style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...estimate.allResults.map((res) {
                      final isSelected = selectedCategories.contains(res.category);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryAccent.withOpacity(0.08) : AppColors.getBg(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryAccent.withOpacity(0.5) : AppColors.getBorder(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            // زر الإضافة الفورية للبند الواحد
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart, color: AppColors.success, size: 22),
                              tooltip: 'إضافة هذا البند فقط للسلة',
                              onPressed: () {
                                if (area <= 0) return;
                                addItemToCartDirect(res, area);
                                HapticsService.actionSuccess();
                                Navigator.pop(ctx);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.success,
                                    content: Text('تمت إضافة [${res.itemName}] (${res.shortSummary}) إلى السلة! 🛒'),
                                  ),
                                );
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                res.shortSummary,
                                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(res.itemName, style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('إجمالي: ${res.totalPieces.toInt()} حبة (معامل: ${res.multiplier})', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                              ],
                            ),
                            Checkbox(
                              value: isSelected,
                              activeColor: AppColors.primaryAccent,
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedCategories.add(res.category);
                                  } else {
                                    selectedCategories.remove(res.category);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.done_all),
                label: Text(
                  selectedCategories.length == estimate.allResults.length
                      ? '📥 إضافة كافة بنود المقايسة للسلة'
                      : '📥 إضافة البنود المحددة (${selectedCategories.length}) للسلة',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedCategories.isNotEmpty ? AppColors.success : AppColors.textSecondary,
                ),
                onPressed: selectedCategories.isEmpty
                    ? null
                    : () {
                        if (area <= 0) return;

                        for (var res in estimate.allResults) {
                          if (selectedCategories.contains(res.category)) {
                            addItemToCartDirect(res, area);
                          }
                        }

                        HapticsService.actionSuccess();
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.success,
                            content: Text('تمت إضافة (${selectedCategories.length}) بنود من مقايسة ($area م²) إلى السلة! 📐🛒'),
                          ),
                        );
                      },
              ),
            ],
          );
        },
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
                          icon: const Icon(Icons.architecture, color: AppColors.success),
                          tooltip: '📐 مقايسة سقف وديكور شاملة بالمتر المربع (م²)',
                          onPressed: () => _showCeilingProjectEstimatorDialog(context, provider),
                        ),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primaryAccent.withOpacity(0.4)),
                              ),
                              child: Text(
                                'الوحدة المسجلة: ${_selectedItem!.unit}',
                                style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const Text('اختر وحدة البيع والسعر المطلوب:', style: TextStyle(color: AppColors.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final availableUnits = List<ProductUnitModel>.from(_selectedItem!.units.where((u) => u.isActive));
                            // إضافة خيار وحدة المتر المربع التلقائية للأصناف الهندسية
                            if (!availableUnits.any((u) => u.unitName.contains('متر مربع') || u.unitName.contains('م²'))) {
                              final cat = CeilingEstimationEngine.detectCategory(_selectedItem!);
                              if (cat != CeilingItemCategory.standard) {
                                availableUnits.add(ProductUnitModel(
                                  id: 'm2-${_selectedItem!.code}',
                                  productCode: _selectedItem!.code,
                                  unitName: 'متر مربع (م²)',
                                  unitType: UnitType.area,
                                  conversionFactor: 1.0,
                                  isBase: false,
                                  salePrice: _selectedItem!.unitPrice,
                                ));
                              }
                            }

                            return DropdownButtonFormField<ProductUnitModel>(
                              value: _selectedUnit ?? availableUnits.firstWhere((u) => u.isBase, orElse: () => availableUnits.first),
                              dropdownColor: AppColors.bgCard,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                labelText: 'وحدة البيع المتاحة للمنتج',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                              ),
                              items: availableUnits.map((u) {
                                final isM2 = u.unitName.contains('متر مربع') || u.unitName.contains('م²');
                                final priceText = u.salePrice != null ? '${u.salePrice} ر.س' : '${(_selectedItem!.unitPrice * u.conversionFactor).toStringAsFixed(2)} ر.س';
                                return DropdownMenuItem<ProductUnitModel>(
                                  value: u,
                                  child: Text(
                                    isM2
                                        ? '📐 ${u.unitName} (حساب معادلة السقف التلقائية)'
                                        : '${u.unitName} (معامل: ${u.conversionFactor} ${_selectedItem!.unit} | سعر: $priceText)',
                                    style: TextStyle(
                                      color: isM2 ? AppColors.success : AppColors.textPrimary,
                                      fontWeight: isM2 ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
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
                            );
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
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'الكمية (${_selectedUnit?.unitName ?? _selectedItem!.unit})',
                                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedUnit != null && (_selectedUnit!.unitName.contains('متر مربع') || _selectedUnit!.unitName.contains('م²'))) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final areaVal = double.tryParse(_qtyController.text) ?? 0.0;
                              if (areaVal > 0) {
                                final res = CeilingEstimationEngine.calculateItemBreakdown(item: _selectedItem!, areaM2: areaVal);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.success.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, color: AppColors.success, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '📐 المعادل الفعلي التلقائي: ${res.formattedBreakdown}',
                                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ] else if (_selectedUnit != null && !_selectedUnit!.isBase) ...[
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
                            'الكمية: ${item['qty']} ${item['unit'] ?? ''} ${item['breakdown_notes'] != null ? '[المعادل: ${item['breakdown_notes']}]' : item['base_qty'] != null && item['base_qty'] != item['qty'] ? '(المكافئ: ${item['base_qty']})' : ''} | سعر الوحدة: ${item['unit_price']} ر.س',
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
