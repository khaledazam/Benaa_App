import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/transfer_model.dart';
import '../providers/inventory_provider.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../widgets/nfc_scanner_dialog.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/enterprise/stock_badge.dart';
import '../widgets/enterprise/enterprise_button.dart';
import '../widgets/enterprise/enterprise_dialog.dart';
import '../widgets/enterprise/enterprise_search_field.dart';

/// Professional Enterprise Transfer Receiving & Physical Audit Screen for Benaa ERP
class TransferAuditDetailScreen extends StatefulWidget {
  final String transferId;

  const TransferAuditDetailScreen({Key? key, required this.transferId}) : super(key: key);

  @override
  State<TransferAuditDetailScreen> createState() => _TransferAuditDetailScreenState();
}

class _TransferAuditDetailScreenState extends State<TransferAuditDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSubmitting = false;

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تقرير جرد ومطابقة الشحنة',
                style: AppTypography.cardTitle(),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'سند تحويل رقم: #${transfer.transferNumber}\n'
                'المصدر: ${transfer.fromWarehouse} ← الوجهة: ${transfer.toWarehouse}\n'
                'محرر السند: ${transfer.author}\n'
                'إجمالي الكمية المطلوبة: ${totalExpected.toInt()}\n'
                'إجمالي الكمية الفعلية المستلمة: ${totalActual.toInt()}\n'
                'عدد البنود ذات الفروقات: ${discrepancies.length}',
                style: AppTypography.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              EnterpriseButton.primary(
                label: 'مشاركة التقرير عبر واتساب / بريد',
                icon: Icons.share_rounded,
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('تم إعداد ملخص المطابقة للمشاركة بنجاح!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
        builder: (context, setDialogState) => EnterpriseDialog(
          title: 'تعديل الكمية والملاحظات',
          icon: Icons.edit_note_rounded,
          confirmLabel: 'حفظ واستلام',
          onConfirm: () {
            final newQty = double.tryParse(qtyController.text) ?? item.actualQty;
            final fullNotes = '${selectedUnit != "حبة" ? "وحدة المستلم: $selectedUnit | " : ""}${notesController.text}';
            Provider.of<InventoryProvider>(context, listen: false).updateItemQuantity(
              item.id!,
              newQty,
              notes: fullNotes,
              imagePath: currentImagePath,
            );
            Navigator.pop(ctx);
          },
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.itemName,
                style: AppTypography.cardTitle(),
              ),
              const SizedBox(height: 4),
              Text(
                'كود الصنف: ${item.itemCode} | الكمية بالفاتورة: ${item.expectedQty}',
                style: AppTypography.secondary(color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: const InputDecoration(labelText: 'وحدة الاستلام'),
                      items: const [
                        DropdownMenuItem(value: 'حبة', child: Text('حبة / قطعة')),
                        DropdownMenuItem(value: 'لوح', child: Text('لوح')),
                        DropdownMenuItem(value: 'متر مربع', child: Text('متر مربع (m²)')),
                        DropdownMenuItem(value: 'كرتونة', child: Text('كرتونة')),
                        DropdownMenuItem(value: 'طبلية', child: Text('طبلية')),
                        DropdownMenuItem(value: 'كيس', child: Text('كيس')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedUnit = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: AppTypography.tabularNumber(fontSize: 18),
                      decoration: const InputDecoration(labelText: 'الفعلي المستلم'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات العجز / التلف إن وجد'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: Icon(
                  currentImagePath != null ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                  color: currentImagePath != null ? AppColors.success : AppColors.primary,
                  size: 18,
                ),
                label: Text(
                  currentImagePath != null ? 'تم توثيق صورة التلف' : 'إرفاق صورة بضاعة تالفة',
                  style: AppTypography.smallLabel(
                    color: currentImagePath != null ? AppColors.success : AppColors.primary,
                  ),
                ),
                onPressed: () async {
                  final capturedPath = 'DAMAGED-${item.itemCode}-${DateTime.now().millisecondsSinceEpoch}.jpg';
                  setDialogState(() => currentImagePath = capturedPath);
                  await HapticsService.scanSuccess();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditInvoiceNotesDialog(BuildContext context, TransferModel transfer) {
    final notesController = TextEditingController(text: transfer.notes ?? '');
    showDialog(
      context: context,
      builder: (ctx) => EnterpriseDialog(
        title: 'ملاحظات سند الشحنة',
        icon: Icons.note_alt_outlined,
        confirmLabel: 'حفظ الملاحظة',
        onConfirm: () async {
          final newNote = notesController.text.trim();
          await Provider.of<InventoryProvider>(context, listen: false).updateInvoiceNotes(transfer.id, newNote);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب أية ملاحظات تشغيلية حول السند أو أسباب الفروقات...',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final transfer = provider.selectedTransfer;

        if (provider.isLoading || transfer == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final items = provider.filteredTransferItems;
        final totalExpected = transfer.items.fold(0.0, (sum, i) => sum + i.expectedQty);
        final totalActual = transfer.items.fold(0.0, (sum, i) => sum + i.actualQty);
        final hasDiscrepancies = transfer.items.any((i) => i.hasDiscrepancy);
        final discrepancyCount = transfer.items.where((i) => i.hasDiscrepancy).length;

        Widget statusBadge;
        if (transfer.status == 'audited_matched' || transfer.status == 'approved') {
          statusBadge = StockBadge.matched(label: 'مكتمل ومطابق');
        } else if (transfer.status == 'audited_discrepancy') {
          statusBadge = StockBadge.discrepancy(label: 'مكتمل بفروقات');
        } else {
          statusBadge = StockBadge.pending(label: 'قيد الجرد والاستلام');
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('تدقيق سند #${transfer.transferNumber}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                tooltip: 'مشاركة التقرير',
                onPressed: () => _showShareReportDialog(context, transfer),
              ),
              IconButton(
                icon: const Icon(Icons.print_outlined, size: 20),
                tooltip: 'طباعة حرارية',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const PrinterSelectionDialog(),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Shipment Overview Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            statusBadge,
                            const SizedBox(width: 8),
                            if (hasDiscrepancies)
                              StockBadge(
                                label: '$discrepancyCount بنود غير مطابقة',
                                backgroundColor: AppColors.errorLight,
                                textColor: AppColors.error,
                              ),
                          ],
                        ),
                        Text(
                          transfer.date,
                          style: AppTypography.smallLabel(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.storefront_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('من: ${transfer.fromWarehouse}', style: AppTypography.bodyBold()),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_back_rounded, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Icon(Icons.warehouse_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('إلى: ${transfer.toWarehouse}', style: AppTypography.bodyBold()),
                        const Spacer(),
                        InkWell(
                          onTap: () => _showEditInvoiceNotesDialog(context, transfer),
                          child: Icon(Icons.note_alt_outlined, size: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Action Toolbar & Fast Scanner Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: EnterpriseButton.secondary(
                        label: 'مطابقة الكل',
                        icon: Icons.done_all_rounded,
                        height: 38,
                        onPressed: () {
                          for (var item in transfer.items) {
                            provider.updateItemQuantity(item.id!, item.expectedQty);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.success,
                              content: Text('تمت مطابقة جميع الكميات بالفاتورة!'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: EnterpriseButton.primary(
                        label: 'مسح باركود',
                        icon: Icons.qr_code_scanner_rounded,
                        height: 38,
                        onPressed: () async {
                          final scanned = await showDialog<String>(
                            context: context,
                            builder: (_) => const CameraScannerDialog(title: 'مسح صنف في الشحنة'),
                          );
                          if (scanned != null && scanned.isNotEmpty) {
                            _searchController.text = scanned;
                            provider.setSearchQuery(scanned);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.nfc_rounded, size: 20),
                      tooltip: 'مسح NFC',
                      color: AppColors.warning,
                      onPressed: () async {
                        final scanned = await showDialog<String>(
                          context: context,
                          builder: (_) => const NfcScannerDialog(),
                        );
                        if (scanned != null && scanned.isNotEmpty) {
                          _searchController.text = scanned;
                          provider.setSearchQuery(scanned);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 3. Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: EnterpriseSearchField(
                  controller: _searchController,
                  hintText: 'بحث بكود الصنف أو الاسم في الشحنة...',
                  onChanged: (val) => provider.setSearchQuery(val),
                ),
              ),

              const SizedBox(height: 8),

              // 4. Checklist Items
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد أصناف مطابقة للبحث',
                          style: AppTypography.secondary(),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemBuilder: (ctx, idx) {
                          final item = items[idx];
                          final isDiff = item.hasDiscrepancy;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDiff
                                  ? (isDark ? const Color(0xFF2D1616) : const Color(0xFFFFF5F5))
                                  : cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDiff ? AppColors.error : borderColor,
                                width: isDiff ? 1.2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEDF2F7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.itemCode,
                                        style: AppTypography.smallLabel(
                                          color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.itemName,
                                        style: AppTypography.cardTitle(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isDiff)
                                      StockBadge.discrepancy(
                                        label: item.discrepancy > 0
                                            ? '+${item.discrepancy}'
                                            : '${item.discrepancy}',
                                      ),
                                  ],
                                ),
                                if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.notes!,
                                    style: AppTypography.smallLabel(color: AppColors.primary),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Stepper & Direct Edit
                                    Row(
                                      children: [
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppColors.error),
                                          onPressed: () {
                                            if (item.actualQty > 0) {
                                              provider.updateItemQuantity(item.id!, item.actualQty - 1);
                                            }
                                          },
                                        ),
                                        InkWell(
                                          onTap: () => _showEditQtyDialog(context, item),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEDF2F7),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: borderColor),
                                            ),
                                            child: Text(
                                              item.actualQty % 1 == 0
                                                  ? item.actualQty.toInt().toString()
                                                  : item.actualQty.toString(),
                                              style: AppTypography.tabularNumber(
                                                fontSize: 16,
                                                color: isDiff ? AppColors.error : AppColors.success,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.add_circle_outline, size: 22, color: AppColors.success),
                                          onPressed: () {
                                            provider.updateItemQuantity(item.id!, item.actualQty + 1);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            item.imagePath != null
                                                ? Icons.photo_library_rounded
                                                : Icons.camera_alt_outlined,
                                            size: 20,
                                            color: item.imagePath != null
                                                ? AppColors.success
                                                : AppColors.textSecondary,
                                          ),
                                          onPressed: () => _showEditQtyDialog(context, item),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'المطلوب بالسند:',
                                          style: AppTypography.smallLabel(color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          '${item.expectedQty % 1 == 0 ? item.expectedQty.toInt() : item.expectedQty}',
                                          style: AppTypography.tabularNumber(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // 5. Sticky Bottom Action Footer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'إجمالي المستلم فعلياً: ',
                                style: AppTypography.body(color: AppColors.textSecondary),
                              ),
                              Text(
                                '${totalActual.toInt()}',
                                style: AppTypography.tabularNumber(
                                  fontSize: 16,
                                  color: hasDiscrepancies ? AppColors.warning : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'إجمالي المطلوب: ',
                                style: AppTypography.body(color: AppColors.textSecondary),
                              ),
                              Text(
                                '${totalExpected.toInt()}',
                                style: AppTypography.tabularNumber(fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      EnterpriseButton.primary(
                        width: double.infinity,
                        height: 46,
                        isLoading: _isSubmitting,
                        label: transfer.status.startsWith('audited')
                            ? 'إعادة تأكيد ومطابقة السند'
                            : 'تأكيد الجرد وإدخال البضاعة للمستودع',
                        icon: Icons.check_circle_outline,
                        onPressed: () async {
                          setState(() => _isSubmitting = true);
                          try {
                            if (hasDiscrepancies) {
                              await HapticsService.warningDiscrepancy();
                              await NotificationService.showDiscrepancyAlert(
                                transferNumber: transfer.transferNumber,
                                discrepancyCount: discrepancyCount,
                              );
                            } else {
                              await HapticsService.actionSuccess();
                            }

                            await provider.confirmSelectedTransferAudit();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: hasDiscrepancies ? AppColors.warning : AppColors.success,
                                  content: Text(
                                    hasDiscrepancies
                                        ? 'تم توثيق الجرد مع وجود $discrepancyCount فروقات عجز/زيادة'
                                        : 'تم إدخال كافة بضاعة الشحنة للمستودع بنجاح وتحديث الأرصدة!',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isSubmitting = false);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
