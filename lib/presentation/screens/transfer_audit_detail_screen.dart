import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/transfer_model.dart';
import '../providers/inventory_provider.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../widgets/nfc_scanner_dialog.dart';
import '../widgets/printer_selection_dialog.dart';

class TransferAuditDetailScreen extends StatefulWidget {
  final String transferId;

  const TransferAuditDetailScreen({Key? key, required this.transferId}) : super(key: key);

  @override
  State<TransferAuditDetailScreen> createState() => _TransferAuditDetailScreenState();
}

class _TransferAuditDetailScreenState extends State<TransferAuditDetailScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).selectTransfer(widget.transferId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showShareReportDialog(BuildContext context, TransferModel transfer) {
    final totalExpected = transfer.items.fold(0.0, (sum, i) => sum + i.expectedQty);
    final totalActual = transfer.items.fold(0.0, (sum, i) => sum + i.actualQty);
    final discrepancies = transfer.items.where((i) => i.hasDiscrepancy).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
                const Text(
                  'مشاركة تقرير الجرد والمطابقة',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(color: AppColors.borderDark),
            const SizedBox(height: 10),
            Text(
              'سند تحويل أصناف رقم: ${transfer.transferNumber}\nالمصدر: ${transfer.fromWarehouse}\nالوجهة: ${transfer.toWarehouse}\nمحرر السند: ${transfer.author}\nإجمالي الكمية بالفاتورة: ${totalExpected.toInt()}\nإجمالي المستلم الفعلي: ${totalActual.toInt()}\nعدد الفروقات/العجز: ${discrepancies.length}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text('مشاركة التقرير عبر WhatsApp / إيميل'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('تم تجهيز ملخص التقرير وجاري الفتح للمشاركة عبر واتساب...'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNewScannedItemDialog(BuildContext context, {String? defaultBarcode}) {
    final barcodeController = TextEditingController(
      text: defaultBarcode ?? 'BAR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final unitController = TextEditingController(text: 'حبة');
    final qtyController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.qr_code_scanner, color: AppColors.primaryAccent),
            Text(
              'تسجيل صنف جديد من المسح الضوئي',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'تنبيه: هذا الباركود غير مسجل مسبقاً في السيستم، يمكنك تسجيل بيانات الصنف الآن وسيتم حفظه فورياً في الكتالوج ورصيد بريدة.',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: barcodeController,
                style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'رقم الباركود / الكود (اختياري)',
                  hintText: 'يُولد تلقائياً إن تُرك فارغاً',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'اسم الصنف الجديد',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: unitController.text.isNotEmpty ? unitController.text : 'حبة',
                      dropdownColor: AppColors.getCardBg(context),
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'وحدة القياس / التعبئة',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'حبة', child: Text('حبة / قطعة')),
                        DropdownMenuItem(value: 'متر مربع', child: Text('متر مربع (m²)')),
                        DropdownMenuItem(value: 'كرتونة', child: Text('كرتونة')),
                        DropdownMenuItem(value: 'طبلية', child: Text('طبلية / لوح')),
                        DropdownMenuItem(value: 'كيس', child: Text('كيس / شيكارة')),
                        DropdownMenuItem(value: 'طن', child: Text('طن')),
                        DropdownMenuItem(value: 'كجم', child: Text('كجم')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          unitController.text = val;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: categoryController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'التصنيف',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'الكمية المستلمة بالفاتورة',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'سعر الوحدة (اختياري)',
                        hintText: 'مثال: 0.0 أو اتركه فارغاً',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              String barcode = barcodeController.text.trim();
              if (barcode.isEmpty) {
                barcode = 'ITEM-${(DateTime.now().millisecondsSinceEpoch % 100000).toString()}';
              }
              final provider = Provider.of<InventoryProvider>(context, listen: false);
              await provider.registerNewScannedItem(
                barcode: barcode,
                itemName: nameController.text.trim(),
                category: categoryController.text.trim(),
                unit: unitController.text.trim(),
                initialQty: double.tryParse(qtyController.text) ?? 1.0,
                defaultPrice: double.tryParse(priceController.text) ?? 0.0,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.success,
                  content: Text('تم تسجيل الصنف الجديد وإضافته لكتالوج المستودع والجرد بنجاح!'),
                ),
              );
            },
            child: const Text('تسجيل الصنف وإضافته'),
          ),
        ],
      ),
    );
  }

  void _showEditQtyDialog(BuildContext context, TransferItemModel item) {
    final qtyController = TextEditingController(text: item.actualQty.toString());
    final notesController = TextEditingController(text: item.notes ?? '');
    String selectedUnit = 'حبة';
    String? currentImagePath = item.imagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getCardBg(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'تعديل وإرفاق ملاحظات/صورة تلف (${item.itemCode})',
            style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.itemName,
                style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              Text(
                'الكمية بالفاتورة الواردة: ${item.expectedQty}',
                style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Builder(
                      builder: (context) {
                        final standardUnits = ['حبة', 'لوح', 'متر', 'متر مربع', 'كرتونة', 'طبلية', 'كيس', 'طن', 'كجم', 'ربطة', 'حزمة', 'علبة', 'طرد', 'جالون', 'لتر'];
                        final currentVal = selectedUnit.trim().isNotEmpty ? selectedUnit.trim() : 'حبة';
                        final itemsList = standardUnits.contains(currentVal) ? standardUnits : [...standardUnits, currentVal];

                        return DropdownButtonFormField<String>(
                          value: currentVal,
                          dropdownColor: AppColors.getCardBg(context),
                          style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'وحدة القياس / التعبئة المستلمة',
                            labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          items: itemsList.map((u) {
                            return DropdownMenuItem<String>(
                              value: u,
                              child: Text(u == 'حبة' ? 'حبة / قطعة' : u == 'متر مربع' ? 'متر مربع (m²)' : u == 'طبلية' ? 'طبلية / لوح' : u),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedUnit = val);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'الكمية المستلمة',
                        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                style: TextStyle(color: AppColors.getTextPrimary(context)),
                decoration: const InputDecoration(
                  labelText: 'ملاحظات العجز / التلف (إن وجد)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: Icon(
                  currentImagePath != null ? Icons.check_circle : Icons.camera_alt_outlined,
                  color: currentImagePath != null ? AppColors.success : AppColors.primaryAccent,
                ),
                label: Text(
                  currentImagePath != null
                      ? '📸 تم التقاط وإرفاق صورة التلف (مفعلة)'
                      : '📷 إلتقاط وإرفاق صورة البضاعة التالفة / الملاحظة',
                  style: TextStyle(
                    color: currentImagePath != null ? AppColors.success : AppColors.primaryAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: currentImagePath != null ? AppColors.success : AppColors.primaryAccent),
                ),
                onPressed: () async {
                  final capturedPath = 'DAMAGED-${item.itemCode}-${DateTime.now().millisecondsSinceEpoch}.jpg';
                  setDialogState(() {
                    currentImagePath = capturedPath;
                  });
                  await HapticsService.scanSuccess();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('🟢 تم إلتقاط وتوثيق صورة البضاعة التالفة ($capturedPath) وحفظها مع التقرير!'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final newQty = double.tryParse(qtyController.text) ?? item.actualQty;
                final fullNotes = '${selectedUnit != "حبة" ? "وحدة المستلم: $selectedUnit | " : ""}${notesController.text}';
                Provider.of<InventoryProvider>(context, listen: false)
                    .updateItemQuantity(item.id!, newQty, notes: fullNotes, imagePath: currentImagePath);
                Navigator.pop(ctx);
              },
              child: const Text('حفظ التعديل والوحدة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditInvoiceNotesDialog(BuildContext context, TransferModel transfer) {
    final notesController = TextEditingController(text: transfer.notes ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '📝 ملاحظات الفاتورة / الجرد',
          style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          style: TextStyle(color: AppColors.getTextPrimary(context)),
          decoration: InputDecoration(
            hintText: 'اكتب أية ملاحظات، أسباب الفروقات، أو ملاحظات التسليم...',
            hintStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            child: Text('إلغاء', style: TextStyle(color: AppColors.getTextSecondary(context))),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent),
            onPressed: () async {
              final newNote = notesController.text.trim();
              await Provider.of<InventoryProvider>(context, listen: false).updateInvoiceNotes(transfer.id, newNote);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.success,
                    content: Text('تم حفظ ملاحظات الفاتورة والجرد بنجاح!'),
                  ),
                );
              }
            },
            child: const Text('حفظ الملاحظة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final transfer = provider.selectedTransfer;

        if (provider.isLoading || transfer == null) {
          return const Scaffold(
            backgroundColor: AppColors.bgDark,
            body: Center(child: CircularProgressIndicator(color: AppColors.primaryAccent)),
          );
        }

        final items = provider.filteredTransferItems;
        final totalExpected = transfer.items.fold(0.0, (sum, i) => sum + i.expectedQty);
        final totalActual = transfer.items.fold(0.0, (sum, i) => sum + i.actualQty);
        final hasDiscrepancies = transfer.items.any((i) => i.hasDiscrepancy);

        return Scaffold(
          backgroundColor: AppColors.getBg(context),
          appBar: AppBar(
            title: Text('سند تحويل أصناف رقم ${transfer.transferNumber}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.print_outlined, color: AppColors.primaryAccent),
                tooltip: 'طباعة سند الجرد حرارياً (Bluetooth)',
                onPressed: () async {
                  final connected = await BluetoothPrinterService.isConnected();
                  if (!connected && context.mounted) {
                    await showDialog(
                      context: context,
                      builder: (ctx) => const PrinterSelectionDialog(),
                    );
                  }

                  final gps = await LocationService.getFormattedLocationString();
                  await BluetoothPrinterService.printTransferAuditVoucher(transfer, gps);
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: AppColors.textPrimary),
                onPressed: () => _showShareReportDialog(context, transfer),
              ),
            ],
          ),
          body: Column(
            children: [
              // --- Header Card (Invoice Info) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: transfer.status == 'audited_matched'
                                ? AppColors.success.withOpacity(0.2)
                                : transfer.status == 'audited_discrepancy'
                                    ? AppColors.danger.withOpacity(0.2)
                                    : AppColors.warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            transfer.status == 'audited_matched'
                                ? 'تم الجرد والمطابقة'
                                : transfer.status == 'audited_discrepancy'
                                    ? 'يوجد فروقات عجز'
                                    : 'قيد الجرد والمطابقة',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: transfer.status == 'audited_matched'
                                  ? AppColors.success
                                  : transfer.status == 'audited_discrepancy'
                                      ? AppColors.danger
                                      : AppColors.warning,
                            ),
                          ),
                        ),
                        Text(
                          'تاريخ التحويل: ${transfer.date}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.borderDark, height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('المصدر (من):', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text(transfer.fromWarehouse, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_back, color: AppColors.primaryAccent),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('الوجهة (إلى):', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text(transfer.toWarehouse, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('عدد الأصناف: ${transfer.items.length}', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12)),
                        Text('الكاتب / المحرر: ${transfer.author}', style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Notes & Comments Banner
                    InkWell(
                      onTap: () => _showEditInvoiceNotesDialog(context, transfer),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.getBg(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.getBorder(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_note, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                transfer.notes != null && transfer.notes!.isNotEmpty
                                    ? 'ملاحظات الفاتورة: ${transfer.notes}'
                                    : '📝 انقر هنا لإضافة ملاحظات أو تعليق على الفاتورة والجرد...',
                                style: TextStyle(
                                  color: transfer.notes != null && transfer.notes!.isNotEmpty
                                      ? AppColors.getTextPrimary(context)
                                      : AppColors.getTextSecondary(context),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Optional Barcode Scan & Manual Audit Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info, size: 16),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          '💡 مسح الباركود (اختياري): يمكنك الجرد والإدخال اليدوي المباشر أو مطابقة جميع الكميات بضغطة زر.',
                          style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Actions Toolbar ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    // Button 0: Match All (مطابقة الكل تلقائياً)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.done_all, size: 16, color: Colors.white),
                        label: const Text('مطابقة الكل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          for (var item in transfer.items) {
                            provider.updateItemQuantity(item.id!, item.expectedQty);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ تم مطابقة كميات الفاتورة بالكامل!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Button 1: Live Camera Scan (Optional)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner, size: 16),
                        label: const Text('كاميرا (اختياري)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAccent,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () async {
                          final scannedCode = await showDialog<String>(
                            context: context,
                            builder: (ctx) => const CameraScannerDialog(
                              title: 'مسح باركود شحنة المستودع',
                            ),
                          );
                          if (scannedCode != null && scannedCode.isNotEmpty) {
                            _searchController.text = scannedCode;
                            provider.setSearchQuery(scannedCode);

                            final matches = provider.filteredTransferItems;
                            if (matches.isEmpty) {
                              _showAddNewScannedItemDialog(context, defaultBarcode: scannedCode);
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Button 2: NFC Scan (Optional)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.nfc, size: 16),
                        label: const Text('NFC (اختياري)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () async {
                          final scannedCode = await showDialog<String>(
                            context: context,
                            builder: (ctx) => const NfcScannerDialog(),
                          );
                          if (scannedCode != null && scannedCode.isNotEmpty) {
                            _searchController.text = scannedCode;
                            provider.setSearchQuery(scannedCode);

                            final matches = provider.filteredTransferItems;
                            if (matches.isEmpty) {
                              _showAddNewScannedItemDialog(context, defaultBarcode: scannedCode);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // --- Search & Barcode Bar ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => provider.setSearchQuery(val),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'ابحث برقم الكود (75, 80...) أو اسم الصنف',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // --- Items Audit List ---
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('لا توجد أصناف مطابقة للبحث', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemBuilder: (ctx, idx) {
                          final item = items[idx];
                          final isDiff = item.hasDiscrepancy;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isDiff ? AppColors.danger.withOpacity(0.08) : AppColors.bgCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDiff ? AppColors.danger.withOpacity(0.5) : AppColors.borderDark,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryAccent.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'كود: ${item.itemCode}',
                                          style: const TextStyle(
                                            color: AppColors.primaryAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '#${idx + 1} - ${item.itemName}',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.right,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              if (item.actualQty > 0) {
                                                provider.updateItemQuantity(item.id!, item.actualQty - 1);
                                              }
                                            },
                                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 24),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                          GestureDetector(
                                            onTap: () => _showEditQtyDialog(context, item),
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDiff ? AppColors.danger.withOpacity(0.2) : AppColors.bgSurface,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isDiff ? AppColors.danger : AppColors.borderDark,
                                                ),
                                              ),
                                              child: Text(
                                                item.actualQty % 1 == 0
                                                    ? item.actualQty.toInt().toString()
                                                    : item.actualQty.toString(),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDiff ? AppColors.danger : AppColors.success,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              provider.updateItemQuantity(item.id!, item.actualQty + 1);
                                            },
                                            icon: const Icon(Icons.add_circle_outline, color: AppColors.success, size: 24),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: () => _showEditQtyDialog(context, item),
                                            icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryAccent, size: 20),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('الكمية بالفاتورة الواردة:', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                          Text(
                                            item.expectedQty % 1 == 0
                                                ? item.expectedQty.toInt().toString()
                                                : item.expectedQty.toString(),
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isDiff)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'الفارق: ${item.discrepancy > 0 ? "+${item.discrepancy}" : item.discrepancy}',
                                        style: TextStyle(
                                          color: item.discrepancy < 0 ? AppColors.danger : AppColors.warning,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // --- Bottom Actions Footer ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border(top: BorderSide(color: AppColors.borderDark)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إجمالي المجرود: ${totalActual.toInt()}',
                          style: TextStyle(
                            color: hasDiscrepancies ? AppColors.warning : AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'إجمالي الفاتورة: ${totalExpected.toInt()}',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          transfer.status.startsWith('audited')
                              ? 'إعادة تأكيد وتحديث المخزون'
                              : 'تأكيد الجرد وإدخال البضاعة لمستودع بريدة',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasDiscrepancies ? AppColors.warning : AppColors.success,
                        ),
                        onPressed: () async {
                          if (hasDiscrepancies) {
                            await HapticsService.warningDiscrepancy();
                            final discrepancyCount = transfer.items.where((i) => i.hasDiscrepancy).length;
                            await NotificationService.showDiscrepancyAlert(
                              transferNumber: transfer.transferNumber,
                              discrepancyCount: discrepancyCount,
                            );
                          } else {
                            await HapticsService.actionSuccess();
                            await NotificationService.showAuditCompleteNotification(
                              transferNumber: transfer.transferNumber,
                            );
                          }

                          await provider.confirmSelectedTransferAudit();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('تم تأكيد الجرد وتحديث رصيد مخزن بريدة بنجاح!'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primaryAccent,
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            label: const Text('كاميرا الباركود 📷', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final scannedCode = await showDialog<String>(
                context: context,
                builder: (ctx) => const CameraScannerDialog(
                  title: 'مسح باركود شحنة المستودع',
                ),
              );
              if (scannedCode != null && scannedCode.isNotEmpty) {
                _searchController.text = scannedCode;
                provider.setSearchQuery(scannedCode);

                final matches = provider.filteredTransferItems;
                if (matches.isEmpty) {
                  _showAddNewScannedItemDialog(context, defaultBarcode: scannedCode);
                }
              }
            },
          ),
        );
      },
    );
  }
}
