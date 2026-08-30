import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/return_invoice_model.dart';
import '../../core/services/pdf_report_service.dart';
import '../providers/inventory_provider.dart';
import '../widgets/create_return_dialog.dart';

import '../../core/services/period_archive_filter_service.dart';
import '../widgets/archive_period_selector_bar.dart';

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
    return Scaffold(
      backgroundColor: AppColors.getBg(context),
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text('↩️ إدارة المرتجعات الشاملة'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.success),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ArchivePeriodSelectorBar(
                    currentPeriod: _archivePeriod,
                    customDateRange: _customDateRange,
                    totalCount: filtered.length,
                    totalAmount: filtered.fold(0.0, (sum, r) => sum + r.totalAmount),
                    countLabel: 'عدد المرتجعات',
                    amountLabel: 'إجمالي مبالغ المرتجعات',
                    onPeriodChanged: (selectedType, range) {
                      setState(() {
                        _archivePeriod = selectedType;
                        _customDateRange = range;
                      });
                    },
                  ),
                ),
              ),
              // Search & Filter Header Bar
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.getCardBg(context),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13),
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'ابحث برقم المرتجع، اسم العميل أو المورد...',
                          hintStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primaryAccent),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('فاتورة مرتجع جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => const CreateReturnDialog(),
                              );
                            },
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildFilterChip('الجميع'),
                              _buildFilterChip('مبيعات'),
                              _buildFilterChip('توريد'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Returns Invoices List
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_return_outlined, color: AppColors.textSecondary, size: 46),
                        const SizedBox(height: 8),
                        Text('لا توجد فواتير مرتجعة مسجلة حالياً', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final item = filtered[idx];
                        final isSales = item.returnType == ReturnType.salesReturn;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: AppColors.getCardBg(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSales ? AppColors.success.withOpacity(0.5) : AppColors.danger.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: ExpansionTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSales ? AppColors.success.withOpacity(0.15) : AppColors.danger.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSales ? Icons.south_west : Icons.north_east,
                                  color: isSales ? AppColors.success : AppColors.danger,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item.totalAmount.toStringAsFixed(2)} ر.س',
                                    style: TextStyle(
                                      color: isSales ? AppColors.success : AppColors.danger,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${item.returnNumber} (${item.partyName})',
                                    style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('التاريخ: ${item.date} | التسوية: ${item.refundMethod}', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSales ? AppColors.success.withOpacity(0.2) : AppColors.danger.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.typeLabel,
                                      style: TextStyle(color: isSales ? AppColors.success : AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                const Divider(height: 1),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  color: AppColors.getBg(context),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('تفاصيل أصناف المرتجع:', style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(height: 6),
                                      ...item.items.map((i) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              children: [
                                                Text('${i.totalPrice.toStringAsFixed(2)} ر.س', style: const TextStyle(color: AppColors.info, fontSize: 11)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${i.itemName} (${i.returnedQty} ${i.unit}) — السبب: ${i.reason}',
                                                    style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                                                    textAlign: TextAlign.right,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ),
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
    return InkWell(
      onTap: () => setState(() => _filterType = label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryAccent : AppColors.getBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primaryAccent : AppColors.getBorder(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.getTextSecondary(context),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
