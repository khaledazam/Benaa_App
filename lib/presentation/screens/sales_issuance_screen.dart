import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
import '../widgets/decoration_estimator_dialog.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../widgets/nfc_scanner_dialog.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/customer_autocomplete_field.dart';
import '../../core/services/period_archive_filter_service.dart';
import '../widgets/archive_period_selector_bar.dart';
import '../widgets/enterprise/enterprise_button.dart';
import '../widgets/enterprise/invoice_summary_card.dart';
import '../widgets/enterprise/section_header.dart';
import '../widgets/enterprise/enterprise_dialog.dart';
import '../widgets/enterprise/stock_badge.dart';

/// Professional Enterprise Sales Issuance & Dispatch Screen for Benaa ERP
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
  ArchivePeriodType _archivePeriod = ArchivePeriodType.allTime;
  DateTimeRange? _customDateRange;

  ItemModel? _selectedItem;
  ProductUnitModel? _selectedUnit;
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  List<Map<String, dynamic>> _cartItems = [];
  bool _isSubmitting = false;

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
          backgroundColor: AppColors.error,
          content: Text('الكمية المطلوبة ($qty $unitName = $baseQty ${_selectedItem!.unit}) تتجاوز الرصيد المتاح (${_selectedItem!.currentStock} ${_selectedItem!.unit})'),
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

  void _confirmAndDispatchSales(BuildContext context) async {
    if (_shopNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة اسم العميل / المحل أولاً')),
      );
      return;
    }

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة! أضف صنفاً واحداً على الأقل')),
      );
      return;
    }

    final totalInvoice = _cartItems.fold(0.0, (sum, i) => sum + (i['total'] as double));

    final confirm = await EnterpriseDialog.showConfirmation(
      context: context,
      title: 'تأكيد اعتماد الفاتورة وصرف المواد',
      message: 'سيتم إصدار فاتورة بيع للعميل (${_shopNameController.text.trim()}) بإجمالي مبلغ ${totalInvoice.toStringAsFixed(2)} ر.س وخصم الكميات من المستودع.',
      confirmLabel: 'اعتماد وصرف',
      icon: Icons.check_circle_outline,
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      final gpsLocation = await LocationService.getFormattedLocationString();
      final saleId = 'SALE-${DateTime.now().millisecondsSinceEpoch}';
      final invoiceNum = _invoiceNumController.text.trim();
      final shopName = _shopNameController.text.trim();
      final dateStr = DateTime.now().toIso8601String().split('T').first;

      await provider.dbHelper.createSaleOrder(
        saleId,
        invoiceNum,
        shopName,
        totalInvoice,
        List<Map<String, dynamic>>.from(_cartItems),
      );

      await provider.loadLocalItems();
      await HapticsService.actionSuccess();

      final saleOrder = SaleOrderModel(
        id: saleId,
        invoiceNumber: invoiceNum,
        shopName: shopName,
        date: dateStr,
        totalAmount: totalInvoice,
        status: 'completed',
        items: _cartItems.map((c) => SaleOrderItemModel(
          saleId: saleId,
          itemCode: c['item_code'].toString(),
          itemName: c['item_name'].toString(),
          qty: (c['qty'] as num).toDouble(),
          unitPrice: (c['unit_price'] as num).toDouble(),
        )).toList(),
      );

      if (mounted) {
        _showInvoiceSuccessDialog(
          context,
          invoiceNum: invoiceNum,
          shopName: shopName,
          date: dateStr,
          totalAmount: totalInvoice,
          items: List.from(_cartItems),
          saleOrder: saleOrder,
          gpsLocation: gpsLocation,
        );

        setState(() {
          _cartItems.clear();
          _invoiceNumController.text = 'INV-BUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          _shopNameController.clear();
          _customerPhoneController.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showInvoiceSuccessDialog(
    BuildContext context, {
    required String invoiceNum,
    required String shopName,
    required String date,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required SaleOrderModel saleOrder,
    required String gpsLocation,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EnterpriseDialog(
        title: 'تم اعتماد وصرف الفاتورة بنجاح',
        icon: Icons.verified_rounded,
        confirmLabel: 'إغلاق ومتابعة',
        onConfirm: () => Navigator.pop(ctx),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'فاتورة رقم: $invoiceNum\nالعميل: $shopName\nالإجمالي: ${totalAmount.toStringAsFixed(2)} ر.س',
              style: AppTypography.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            EnterpriseButton.secondary(
              label: 'طباعة فاتورة ضريبية رسمية (A4 / PDF)',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: () async {
                final pdfBytes = await PdfReportService.generateSaleInvoicePdf(
                  invoiceNumber: invoiceNum,
                  shopName: shopName,
                  date: date,
                  totalAmount: totalAmount,
                  items: items,
                );
                await Printing.layoutPdf(onLayout: (_) => pdfBytes);
              },
            ),
            const SizedBox(height: 8),
            EnterpriseButton.secondary(
              label: 'إرسال إشعار تسليم بضاعة للعميل (واتساب)',
              icon: Icons.share_rounded,
              onPressed: () async {
                final pdfBytes = await PdfReportService.generateGoodsDeliveryVoucherPdf(
                  invoiceNumber: invoiceNum,
                  warehouseName: 'مستودع بريدة الرئيسي',
                  customerName: shopName,
                  customerCode: '320',
                  representative: 'أمين المستودع',
                  date: date,
                  address: 'بريدة',
                  author: 'MOHAMED',
                  time: date,
                  notes: 'إذن صرف وتسليم بضاعة',
                  items: items,
                );
                await Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: 'اذن_تسليم_$invoiceNum.pdf',
                );
              },
            ),
            const SizedBox(height: 8),
            EnterpriseButton.secondary(
              label: 'طباعة حرارية عبر البلوتوث (Thermal)',
              icon: Icons.print_outlined,
              onPressed: () async {
                final isPrinterConnected = await BluetoothPrinterService.isConnected();
                if (!isPrinterConnected && ctx.mounted) {
                  showDialog(
                    context: ctx,
                    builder: (_) => const PrinterSelectionDialog(),
                  );
                } else {
                  await BluetoothPrinterService.printSalesIssuanceReceipt(
                    saleOrder,
                    gpsLocation,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    final subtotal = _cartItems.fold(0.0, (sum, i) => sum + (i['total'] as double));
    final vatAmount = subtotal * 0.15;
    final grandTotal = subtotal + vatAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسليم بضاعة وفواتير بيع (صرف لعميل)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined, size: 20),
            tooltip: 'حاسبة مقايسة الديكور والأسقف',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => DecorationEstimatorDialog(
                  onAddItemsToCart: (newItems) {
                    setState(() => _cartItems.addAll(newItems));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('تمت إضافة (${newItems.length}) بنود من المقايسة إلى السلة!'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final items = provider.localItems.where((i) => i.currentStock > 0).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // 1. Customer & Invoice Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('بيانات العميل والفاتورة', style: AppTypography.sectionHeading()),
                    const SizedBox(height: 12),
                    CustomerAutocompleteField(
                      controller: _shopNameController,
                      labelText: 'اسم المحل / العميل',
                      onCustomerSelected: (customer) {
                        setState(() => _customerPhoneController.text = customer.phone);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customerPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'رقم هاتف العميل'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _invoiceNumController,
                            decoration: const InputDecoration(labelText: 'رقم الفاتورة'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Add Item to Cart Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 8,
                      children: [
                        Text('إضافة أصناف للسلة', style: AppTypography.sectionHeading()),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                              color: AppColors.primary,
                              tooltip: 'مسح باركود',
                              onPressed: () async {
                                final scanned = await showDialog<String>(
                                  context: context,
                                  builder: (_) => const CameraScannerDialog(title: 'مسح باركود الصنف للمبيعات'),
                                );
                                if (scanned != null && scanned.isNotEmpty) {
                                  final match = items.where((i) => i.code == scanned.trim());
                                  if (match.isNotEmpty) {
                                    setState(() {
                                      _selectedItem = match.first;
                                      _priceController.text = _selectedItem!.unitPrice > 0
                                          ? _selectedItem!.unitPrice.toString()
                                          : '';
                                    });
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.nfc_rounded, size: 20),
                              color: AppColors.warning,
                              tooltip: 'مسح NFC',
                              onPressed: () async {
                                final scanned = await showDialog<String>(
                                  context: context,
                                  builder: (_) => const NfcScannerDialog(),
                                );
                                if (scanned != null && scanned.isNotEmpty) {
                                  final match = items.where((i) => i.code == scanned.trim());
                                  if (match.isNotEmpty) {
                                    setState(() {
                                      _selectedItem = match.first;
                                      _priceController.text = _selectedItem!.unitPrice > 0
                                          ? _selectedItem!.unitPrice.toString()
                                          : '';
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

                    // Product Dropdown
                    DropdownButtonFormField<ItemModel>(
                      value: _selectedItem,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'اختر الصنف من المستودع'),
                      items: items.map((i) {
                        return DropdownMenuItem<ItemModel>(
                          value: i,
                          child: Text(
                            '${i.name} (متاح: ${i.currentStock % 1 == 0 ? i.currentStock.toInt() : i.currentStock} ${i.unit})',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(),
                          ),
                        );
                      }).toList(),
                      onChanged: (item) {
                        setState(() {
                          _selectedItem = item;
                          _priceController.text = item != null && item.unitPrice > 0
                              ? item.unitPrice.toString()
                              : '';
                        });
                      },
                    ),

                    if (_selectedItem != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: AppTypography.tabularNumber(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'الكمية المطلوبة (${_selectedItem!.unit})',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: AppTypography.tabularNumber(fontSize: 16),
                              decoration: const InputDecoration(labelText: 'سعر الوحدة (ر.س)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      EnterpriseButton.primary(
                        label: 'إضافة الصنف إلى فاتورة الصرف',
                        icon: Icons.add_shopping_cart_rounded,
                        onPressed: _addItemToCart,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Cart Items List
              SectionHeader(
                title: 'الأصناف المضافة بالسلة',
                count: _cartItems.length,
              ),

              if (_cartItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'لم يتم إضافة أصناف إلى سلة الفاتورة بعد',
                      style: AppTypography.secondary(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ..._cartItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['item_name'],
                                style: AppTypography.cardTitle(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item['qty']} ${item['unit']} × ${item['unit_price']} ر.س',
                                style: AppTypography.secondary(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${(item['total'] as double).toStringAsFixed(2)} ر.س',
                              style: AppTypography.tabularNumber(
                                fontSize: 15,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                              onPressed: () {
                                setState(() => _cartItems.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),

              const SizedBox(height: 14),

              // 4. Financial Summary Card
              if (_cartItems.isNotEmpty) ...[
                InvoiceSummaryCard(
                  subtotal: subtotal,
                  vatAmount: vatAmount,
                  grandTotal: grandTotal,
                  remainingBalance: grandTotal,
                ),
                const SizedBox(height: 16),
                EnterpriseButton.primary(
                  width: double.infinity,
                  height: 48,
                  isLoading: _isSubmitting,
                  label: 'اعتماد الفاتورة وصرف البضاعة من المستودع',
                  icon: Icons.check_circle_outline,
                  onPressed: () => _confirmAndDispatchSales(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
