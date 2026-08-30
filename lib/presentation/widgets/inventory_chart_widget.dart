import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/item_model.dart';

class InventoryChartWidget extends StatefulWidget {
  final List<ItemModel> items;
  const InventoryChartWidget({Key? key, required this.items}) : super(key: key);

  @override
  State<InventoryChartWidget> createState() => _InventoryChartWidgetState();
}

class _InventoryChartWidgetState extends State<InventoryChartWidget> {
  int _selectedTab = 0; // 0: حسب التصنيف, 1: تحليلات الحركة
  int _selectedPeriod = 1; // 0: يومي, 1: أسبوعي, 2: شهري

  @override
  Widget build(BuildContext context) {
    final Map<String, double> categoryStock = {};
    for (var item in widget.items) {
      categoryStock[item.category] = (categoryStock[item.category] ?? 0.0) + item.currentStock;
    }

    final sortedCategories = categoryStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxStock = sortedCategories.isEmpty
        ? 100.0
        : sortedCategories.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    // Dynamic movement data based on period filter
    final List<Map<String, dynamic>> movementData = _selectedPeriod == 0
        ? [ // Daily (Today's Hours)
            {'day': '08:00 ص', 'in': 50.0, 'out': 10.0},
            {'day': '10:00 ص', 'in': 120.0, 'out': 40.0},
            {'day': '12:00 م', 'in': 30.0, 'out': 90.0},
            {'day': '02:00 م', 'in': 80.0, 'out': 60.0},
            {'day': '04:00 م', 'in': 150.0, 'out': 30.0},
          ]
        : _selectedPeriod == 1
            ? [ // Weekly
                {'day': 'السبت', 'in': 120.0, 'out': 45.0},
                {'day': 'الأحد', 'in': 80.0, 'out': 90.0},
                {'day': 'الإثنين', 'in': 200.0, 'out': 150.0},
                {'day': 'الثلاثاء', 'in': 150.0, 'out': 80.0},
                {'day': 'الأربعاء', 'in': 90.0, 'out': 110.0},
                {'day': 'الخميس', 'in': 300.0, 'out': 220.0},
              ]
            : [ // Monthly (Weeks 1 to 4)
                {'day': 'الأسبوع 1', 'in': 600.0, 'out': 450.0},
                {'day': 'الأسبوع 2', 'in': 850.0, 'out': 700.0},
                {'day': 'الأسبوع 3', 'in': 400.0, 'out': 550.0},
                {'day': 'الأسبوع 4', 'in': 1100.0, 'out': 920.0},
              ];

    return Card(
      color: AppColors.getCardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.getBorder(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              spacing: 8,
              children: [
                Text(
                  '📊 تحليلات المخزون',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabBtn('التصنيف', 0),
                    const SizedBox(width: 6),
                    _buildTabBtn('الحركة', 1),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Period Selector Chips (Daily / Weekly / Monthly)
            if (_selectedTab == 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildPeriodBtn('📅 يومي', 0),
                  const SizedBox(width: 6),
                  _buildPeriodBtn('🗓️ أسبوعي', 1),
                  const SizedBox(width: 6),
                  _buildPeriodBtn('📆 شهري', 2),
                ],
              ),

            const SizedBox(height: 16),

            if (_selectedTab == 0) ...[
              if (sortedCategories.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('لا توجد بيانات أصناف حالياً', style: TextStyle(color: AppColors.getTextSecondary(context))),
                  ),
                )
              else
                Column(
                  children: sortedCategories.take(5).map((entry) {
                    final ratio = (entry.value / (maxStock == 0 ? 1 : maxStock)).clamp(0.05, 1.0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${entry.value.toInt()} وحدة',
                                style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                entry.key,
                                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 10,
                              backgroundColor: AppColors.getSurfaceBg(context),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ] else ...[
              // Period Comparison Movement Chart
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: movementData.map((d) {
                  final maxVal = _selectedPeriod == 2 ? 1200.0 : 300.0;
                  final inHeight = ((d['in'] as double) / maxVal * 100).clamp(15.0, 100.0);
                  final outHeight = ((d['out'] as double) / maxVal * 100).clamp(15.0, 100.0);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 12,
                            height: inHeight,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 12,
                            height: outHeight,
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d['day'] as String,
                        style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 4),
                      Text('صرف / بيع', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 4),
                      Text('وارد / استلام', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabBtn(String label, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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

  Widget _buildPeriodBtn(String label, int periodIndex) {
    final isSelected = _selectedPeriod == periodIndex;
    return InkWell(
      onTap: () => setState(() => _selectedPeriod = periodIndex),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryAccent.withOpacity(0.2) : AppColors.getBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primaryAccent : AppColors.getBorder(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryAccent : AppColors.getTextSecondary(context),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
