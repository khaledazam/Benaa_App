import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/inventory_provider.dart';
import 'transfer_audit_detail_screen.dart';
import '../widgets/create_transfer_dialog.dart';
import '../../core/services/period_archive_filter_service.dart';
import '../widgets/archive_period_selector_bar.dart';

class TransfersListScreen extends StatefulWidget {
  const TransfersListScreen({Key? key}) : super(key: key);

  @override
  State<TransfersListScreen> createState() => _TransfersListScreenState();
}

class _TransfersListScreenState extends State<TransfersListScreen> {
  ArchivePeriodType _archivePeriod = ArchivePeriodType.allTime;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadTransfers();
    });
  }

  void _openCreateInvoiceDialog(BuildContext context) async {
    final transferId = await showDialog<String>(
      context: context,
      builder: (ctx) => const CreateTransferDialog(),
    );
    if (transferId != null && transferId.isNotEmpty && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => TransferAuditDetailScreen(transferId: transferId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBg(context),
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text('فواتير التحويل الواردة'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add, color: AppColors.success),
            tooltip: 'إنشاء فاتورة جديدة من السفر',
            onPressed: () => _openCreateInvoiceDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryAccent),
            tooltip: 'إعادة تحميل الفواتير',
            onPressed: () {
              Provider.of<InventoryProvider>(context, listen: false).loadTransfers();
            },
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final allTransfers = provider.transfers;

          final transfers = allTransfers.where((t) {
            return PeriodArchiveFilterService.isDateStringInPeriod(
              dateStr: t.date,
              periodType: _archivePeriod,
              customRange: _customDateRange,
            );
          }).toList();

          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ArchivePeriodSelectorBar(
                    currentPeriod: _archivePeriod,
                    customDateRange: _customDateRange,
                    totalCount: transfers.length,
                    totalAmount: 0.0,
                    countLabel: 'فواتير الفترة',
                    amountLabel: 'الإجمالي',
                    onPeriodChanged: (selectedType, range) {
                      setState(() {
                        _archivePeriod = selectedType;
                        _customDateRange = range;
                      });
                    },
                  ),
                ),
              ),
              if (transfers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد فواتير تحويل واردة لهذه الفترة الأرشيفية',
                            style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 14, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final t = transfers[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: AppColors.getCardBg(context),
                        child: ListTile(
                          title: Text('فاتورة تحويل رقم: ${t.transferNumber}', style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold)),
                          subtitle: Text('المصدر: ${t.fromWarehouse} | التاريخ: ${t.date}', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  (t.status == 'approved' || t.status == 'audited_matched')
                                      ? 'مكتملة ومستلمة 🟢'
                                      : t.status == 'audited_discrepancy'
                                          ? 'مكتملة بفارق ⚠️'
                                          : 'قيد التدقيق ⏳',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                                backgroundColor: (t.status == 'approved' || t.status == 'audited_matched')
                                    ? AppColors.success
                                    : t.status == 'audited_discrepancy'
                                        ? AppColors.danger
                                        : AppColors.warning,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                tooltip: 'حذف الفاتورة',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: AppColors.getCardBg(context),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Text('⚠️ تأكيد حذف فاتورة التحويل', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                                      content: Text('هل أنت متأكد من حذف فاتورة التحويل (${t.transferNumber})؟', style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13), textAlign: TextAlign.right),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                          onPressed: () async {
                                            Navigator.pop(c);
                                            await Provider.of<InventoryProvider>(context, listen: false).deleteTransfer(t.id);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(backgroundColor: AppColors.success, content: Text('تم حذف الفاتورة (${t.transferNumber}) بنجاح 🗑️')),
                                              );
                                            }
                                          },
                                          child: const Text('نعم، حذف'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (ctx) => TransferAuditDetailScreen(transferId: t.id)),
                            );
                          },
                        ),
                      );
                    },
                    childCount: transfers.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
