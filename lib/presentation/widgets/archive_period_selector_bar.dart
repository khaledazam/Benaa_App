import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/period_archive_filter_service.dart';

class ArchivePeriodSelectorBar extends StatelessWidget {
  final ArchivePeriodType currentPeriod;
  final DateTimeRange? customDateRange;
  final Function(ArchivePeriodType selectedType, DateTimeRange? range) onPeriodChanged;
  final int totalCount;
  final double totalAmount;
  final String countLabel;
  final String amountLabel;

  const ArchivePeriodSelectorBar({
    Key? key,
    required this.currentPeriod,
    this.customDateRange,
    required this.onPeriodChanged,
    this.totalCount = 0,
    this.totalAmount = 0.0,
    this.countLabel = 'عدد الفواتير',
    this.amountLabel = 'الإجمالي المالـي',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            spacing: 8,
            children: [
              if (totalAmount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Text(
                    '$amountLabel: ${totalAmount.toStringAsFixed(0)} ر.س',
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$countLabel: $totalCount',
                  style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'جدولة:',
                    style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.calendar_month_outlined, color: AppColors.primaryAccent, size: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildChip(context, 'اليوم 📅', ArchivePeriodType.today),
              _buildChip(context, 'هذا الأسبوع 🗓️', ArchivePeriodType.thisWeek),
              _buildChip(context, 'هذا الشهر 📆', ArchivePeriodType.thisMonth),
              _buildChip(context, 'الأرشيف الكامل 📁', ArchivePeriodType.allTime),
              _buildCustomChip(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, ArchivePeriodType type) {
    final isSelected = currentPeriod == type;
    return InkWell(
      onTap: () => onPeriodChanged(type, null),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryAccent : AppColors.getBg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primaryAccent : AppColors.getBorder(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.getTextSecondary(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomChip(BuildContext context) {
    final isSelected = currentPeriod == ArchivePeriodType.custom;
    final label = customDateRange != null
        ? '${customDateRange!.start.toString().substring(5, 10)} ➔ ${customDateRange!.end.toString().substring(5, 10)} 🔍'
        : 'تاريخ مخصص 🔍';

    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2025),
          lastDate: DateTime(2030),
          initialDateRange: customDateRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primaryAccent,
                  onPrimary: Colors.white,
                  surface: AppColors.bgSurface,
                  onSurface: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          onPeriodChanged(ArchivePeriodType.custom, picked);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.warning : AppColors.getBg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.warning : AppColors.getBorder(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.getTextSecondary(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
