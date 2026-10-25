import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';

/// Professional Commercial Invoice Financial Summary Card
class InvoiceSummaryCard extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double vatAmount;
  final double grandTotal;
  final double paidAmount;
  final double remainingBalance;

  const InvoiceSummaryCard({
    Key? key,
    required this.subtotal,
    this.discount = 0.0,
    required this.vatAmount,
    required this.grandTotal,
    this.paidAmount = 0.0,
    required this.remainingBalance,
  }) : super(key: key);

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required double amount,
    bool isBold = false,
    bool isTotal = false,
    Color? customColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final valueColor = customColor ?? defaultColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? AppTypography.cardTitle(color: defaultColor)
                : (isBold
                    ? AppTypography.bodyBold(color: defaultColor)
                    : AppTypography.body(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount.toStringAsFixed(2),
                style: AppTypography.tabularNumber(
                  fontSize: isTotal ? 17 : 14,
                  fontWeight: isTotal || isBold ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'ر.س',
                style: AppTypography.smallLabel(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
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
            'الملخص المالي للفاتورة',
            style: AppTypography.cardTitle(
              color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildRow(context, label: 'المجموع قبل الضريبة:', amount: subtotal),
          if (discount > 0)
            _buildRow(context, label: 'الخصم الممنوح:', amount: discount, customColor: AppColors.error),
          _buildRow(context, label: 'ضريبة القيمة المضافة (15%):', amount: vatAmount),
          const SizedBox(height: 6),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 6),
          _buildRow(context, label: 'الإجمالي الصافي:', amount: grandTotal, isTotal: true),
          if (paidAmount > 0) ...[
            const SizedBox(height: 4),
            _buildRow(context, label: 'المدفوع نقداً/تحويل:', amount: paidAmount, customColor: AppColors.success),
          ],
          if (remainingBalance > 0) ...[
            const SizedBox(height: 4),
            _buildRow(
              context,
              label: 'المتبقي (آجل على الحساب):',
              amount: remainingBalance,
              isBold: true,
              customColor: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}
