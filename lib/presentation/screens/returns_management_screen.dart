import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/return_invoice_model.dart';
import '../../core/services/pdf_report_service.dart';
import 'package:printing/printing.dart';
import '../providers/inventory_provider.dart';
import '../widgets/create_return_dialog.dart';
import '../../core/services/period_archive_filter_service.dart';
import '../widgets/archive_period_selector_bar.dart';
import '../widgets/enterprise/enterprise_search_field.dart';
import '../widgets/enterprise/stock_badge.dart';
import '../widgets/enterprise/enterprise_dialog.dart';
import '../widgets/enterprise/enterprise_empty_state.dart';

/// Professional Enterprise Returns Management Screen for Benaa ERP
class ReturnsManagementScreen extends StatefulWidget {
  const ReturnsManagementScreen({Key? key}) : super(key: key);

  @override
  State<ReturnsManagementScreen> createState() => _ReturnsManagementScreenState();
}

class _ReturnsManagementScreenState extends State<ReturnsManagementScreen> {
  String _filterType = 'الجميع';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ArchivePeriodType _archivePeriod = ArchivePeriodType.allTime;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadReturns();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة فواتير المرتجعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: 'إنشاء فاتورة مرتجع جديدة',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const CreateReturnDialog(),
              );
            },
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final returnsList = provider.returns;

          final filtered = returnsList.where((r) {
            final matchesQuery = _searchQuery.isEmpty ||
                r.returnNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                r.partyName.toLowerCase().contains(_searchQuery.toLowerCase());

            bool matchesType = true;
            if (_filterType == 'مبيعات') {
              matchesType = r.returnType == ReturnType.salesReturn;
            } else if (_filterType == 'توريد') {
              matchesType = r.returnType == ReturnType.purchaseReturn;
            }

            final matchesPeriod = PeriodArchiveFilterService.isDateStringInPeriod(
              dateStr: r.date,
              periodType: _archivePeriod,
              customRange: _customDateRange,
            );

            return matchesQuery && matchesType && matchesPeriod;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      EnterpriseSearchField(
                        controller: _searchController,
                        hintText: 'بحث برقم المرتجع أو اسم العميل / المورد...',
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildFilterChip('الجميع'),
                          const SizedBox(width: 6),
                          _buildFilterChip('مبيعات'),
                          const SizedBox(width: 6),
                          _buildFilterChip('توريد'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ArchivePeriodSelectorBar(
                        currentPeriod: _archivePeriod,
                        customDateRange: _customDateRange,
                        totalCount: filtered.length,
                        totalAmount: filtered.fold(0.0, (sum, r) => sum + r.totalAmount),
                        countLabel: 'عدد المرتجعات',
                        amountLabel: 'إجمالي المبالغ',
                        onPeriodChanged: (selectedType, range) {
                          setState(() {
                            _archivePeriod = selectedType;
                            _customDateRange = range;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EnterpriseEmptyState(
                    icon: Icons.assignment_return_outlined,
                    title: 'لا توجد فواتير مرتجعات مسجلة',
                    message: 'يمكنك إنشاء فاتورة إرجاع بضاعة جديدة بالضغط على زر الإضافة أعلاه',
                    actionLabel: 'إنشاء مرتجع جديد',
                    onAction: () {
                      showDialog(
                        context: context,
                        builder: (_) => const CreateReturnDialog(),
                      );
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final r = filtered[idx];
                        final isSalesReturn = r.returnType == ReturnType.salesReturn;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      StockBadge(
                                        label: isSalesReturn ? 'مرتجع مبيعات' : 'مرتجع توريد',
                                        backgroundColor: isSalesReturn ? AppColors.warningLight : AppColors.infoLight,
                                        textColor: isSalesReturn ? AppColors.warning : AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '#${r.returnNumber}',
                                        style: AppTypography.smallLabel(
                                          color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    r.date,
                                    style: AppTypography.smallLabel(
                                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.partyName,
                                          style: AppTypography.cardTitle(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (r.notes.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'ملاحظات: ${r.notes}',
                                            style: AppTypography.secondary(
                                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${r.totalAmount.toStringAsFixed(2)} ر.س',
                                    style: AppTypography.tabularNumber(
                                      fontSize: 16,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                    tooltip: 'طباعة إشعار المرتجع',
                                    color: AppColors.primary,
                                    onPressed: () async {
                                      final pdfBytes = await PdfReportService.generateGoodsReceiptVoucherPdf(
                                        voucherNumber: r.returnNumber,
                                        recipientName: r.partyName,
                                        date: DateTime.tryParse(r.date) ?? DateTime.now(),
                                        items: r.items.map((i) => {
                                          'quantity': i.returnedQty,
                                          'name': '${i.itemName} (${i.reason})',
                                          'unit': i.unit,
                                          'price': i.unitPrice,
                                        }).toList(),
                                        notes: r.notes,
                                      );
                                      await Printing.layoutPdf(
                                        onLayout: (format) async => pdfBytes,
                                        name: 'سند_مرتجع_${r.returnNumber}.pdf',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterType == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(
        label,
        style: AppTypography.smallLabel(
          color: isSelected
              ? Colors.white
              : (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEDF2F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide.none,
      onSelected: (_) => setState(() => _filterType = label),
    );
  }
}
