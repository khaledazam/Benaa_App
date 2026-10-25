import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item_model.dart';
import '../providers/inventory_provider.dart';
import '../../core/services/haptics_service.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../../core/services/period_archive_filter_service.dart';
import '../widgets/archive_period_selector_bar.dart';
import '../widgets/enterprise/stock_badge.dart';
import '../widgets/enterprise/enterprise_button.dart';
import '../widgets/enterprise/section_header.dart';

/// Professional Enterprise Stock Take & Physical Inventory Count Screen for Benaa
class StockAuditScreen extends StatefulWidget {
  const StockAuditScreen({Key? key}) : super(key: key);

  @override
  State<StockAuditScreen> createState() => _StockAuditScreenState();
}

class _StockAuditScreenState extends State<StockAuditScreen> {
  ItemModel? _selectedItem;
  final TextEditingController _countedQtyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  ArchivePeriodType _archivePeriod = ArchivePeriodType.allTime;
  DateTimeRange? _customDateRange;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Provider.of<InventoryProvider>(context, listen: false);
      p.loadLocalItems();
      p.loadAuditLogs();
    });
  }

  @override
  void dispose() {
    _countedQtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveAuditRecord(BuildContext context) async {
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الصنف أولاً')),
      );
      return;
    }

    final counted = double.tryParse(_countedQtyController.text);
    if (counted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال كمية مجرودة صحيحة')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      await provider.recordPeriodicAudit(
        _selectedItem!.code,
        _selectedItem!.name,
        _selectedItem!.currentStock,
        counted,
        _notesController.text,
      );

      await HapticsService.actionSuccess();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('تم توثيق عملية الجرد وتحديث رصيد المستودع بنجاح!'),
          ),
        );
        setState(() {
          _selectedItem = null;
          _countedQtyController.clear();
          _notesController.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجرد الفعلي للأرصدة (عند الطلب)'),
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final items = provider.localItems;
          final allLogs = provider.auditLogs;

          final filteredLogs = allLogs.where((log) {
            final dateStr = log['auditDate'] ?? log['date'] ?? '';
            return PeriodArchiveFilterService.isDateStringInPeriod(
              dateStr: dateStr.toString(),
              periodType: _archivePeriod,
              customRange: _customDateRange,
            );
          }).toList();

          double countedQty = double.tryParse(_countedQtyController.text) ?? 0.0;
          double systemQty = _selectedItem?.currentStock ?? 0.0;
          double diff = countedQty - systemQty;
          bool hasDiff = _countedQtyController.text.isNotEmpty && diff != 0.0;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // 1. Audit Entry Box
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
                    Text(
                      'تسجيل جرد فعلي لصنف',
                      style: AppTypography.sectionHeading(),
                    ),
                    const SizedBox(height: 12),

                    // Item Selector with Scanner Trigger
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ItemModel>(
                            value: _selectedItem,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'اختر الصنف من المخزن',
                            ),
                            items: items.map((i) {
                              return DropdownMenuItem<ItemModel>(
                                value: i,
                                child: Text(
                                  '${i.name} (${i.code})',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(),
                                ),
                              );
                            }).toList(),
                            onChanged: (item) {
                              setState(() {
                                _selectedItem = item;
                                _countedQtyController.text = item != null
                                    ? (item.currentStock % 1 == 0
                                        ? item.currentStock.toInt().toString()
                                        : item.currentStock.toString())
                                    : '';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                          color: AppColors.primary,
                          tooltip: 'مسح الباركود',
                          onPressed: () async {
                            final scanned = await showDialog<String>(
                              context: context,
                              builder: (_) => const CameraScannerDialog(title: 'مسح باركود الصنف للجرد'),
                            );
                            if (scanned != null && scanned.isNotEmpty) {
                              final matched = items.where((i) => i.code == scanned.trim() || i.name.contains(scanned.trim()));
                              if (matched.isNotEmpty) {
                                setState(() {
                                  _selectedItem = matched.first;
                                  _countedQtyController.text = _selectedItem!.currentStock % 1 == 0
                                      ? _selectedItem!.currentStock.toInt().toString()
                                      : _selectedItem!.currentStock.toString();
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),

                    if (_selectedItem != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الرصيد الدفتري المسجل:',
                                    style: AppTypography.smallLabel(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${systemQty % 1 == 0 ? systemQty.toInt() : systemQty} ${_selectedItem!.unit}',
                                    style: AppTypography.tabularNumber(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _countedQtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: AppTypography.tabularNumber(fontSize: 18),
                              decoration: InputDecoration(
                                labelText: 'الرصيد الفعلي المجرود (${_selectedItem!.unit})',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      if (hasDiff) ...[
                        const SizedBox(height: 8),
                        StockBadge.discrepancy(
                          label: 'الفارق عن الدفتري: ${diff > 0 ? "+${diff % 1 == 0 ? diff.toInt() : diff}" : (diff % 1 == 0 ? diff.toInt() : diff)} ${_selectedItem!.unit}',
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات وتبرير الفارق (إن وجد)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      EnterpriseButton.primary(
                        label: 'اعتماد نتيجة الجرد وتحديث الرصيد',
                        icon: Icons.check_circle_outline,
                        isLoading: _isSaving,
                        onPressed: () => _saveAuditRecord(context),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Archive Filter Bar
              ArchivePeriodSelectorBar(
                currentPeriod: _archivePeriod,
                customDateRange: _customDateRange,
                totalCount: filteredLogs.length,
                totalAmount: 0.0,
                countLabel: 'عمليات الجرد',
                amountLabel: 'الإجمالي',
                onPeriodChanged: (selectedType, range) {
                  setState(() {
                    _archivePeriod = selectedType;
                    _customDateRange = range;
                  });
                },
              ),

              const SizedBox(height: 12),

              // 3. Audit Logs History List
              SectionHeader(
                title: 'سجل عمليات الجرد السابقة',
                count: filteredLogs.length,
              ),

              if (filteredLogs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'لا توجد عمليات جرد مسجلة لهذه الفترة',
                      style: AppTypography.secondary(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...filteredLogs.map((log) {
                  final logDate = log['auditDate'] ?? log['date'] ?? '';
                  final itemName = log['itemName'] ?? log['name'] ?? '';
                  final itemCode = log['itemCode'] ?? log['code'] ?? '';
                  final oldQty = (log['systemQty'] ?? log['oldStock'] ?? 0.0).toDouble();
                  final newQty = (log['countedQty'] ?? log['newStock'] ?? 0.0).toDouble();
                  final logDiff = newQty - oldQty;

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
                                itemName,
                                style: AppTypography.cardTitle(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'كود: $itemCode | التاريخ: $logDate',
                                style: AppTypography.smallLabel(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'من ${oldQty % 1 == 0 ? oldQty.toInt() : oldQty} ← ${newQty % 1 == 0 ? newQty.toInt() : newQty}',
                                  style: AppTypography.tabularNumber(fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            StockBadge(
                              label: logDiff == 0
                                  ? 'مطابق'
                                  : (logDiff > 0 ? 'فائض +$logDiff' : 'عجز $logDiff'),
                              backgroundColor: logDiff == 0
                                  ? AppColors.successLight
                                  : (logDiff > 0 ? AppColors.warningLight : AppColors.errorLight),
                              textColor: logDiff == 0
                                  ? AppColors.success
                                  : (logDiff > 0 ? AppColors.warning : AppColors.error),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          );
        },
      ),
    );
  }
}
