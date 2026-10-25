import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';
import 'stock_badge.dart';

/// Clean Customer Ledger & Debt Overview Card
class CustomerBalanceCard extends StatelessWidget {
  final String customerName;
  final String? phone;
  final double currentBalance;
  final double? creditLimit;
  final VoidCallback? onStatementTap;
  final VoidCallback? onPaymentTap;

  const CustomerBalanceCard({
    Key? key,
    required this.customerName,
    this.phone,
    required this.currentBalance,
    this.creditLimit,
    this.onStatementTap,
    this.onPaymentTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    final isOverLimit = creditLimit != null && currentBalance > creditLimit!;
    final hasDebt = currentBalance > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverLimit ? AppColors.error : borderColor,
          width: isOverLimit ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  customerName,
                  style: AppTypography.cardTitle(
                    color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOverLimit)
                StockBadge(
                  label: 'تجاوز حد الائتمان',
                  backgroundColor: AppColors.errorLight,
                  textColor: AppColors.error,
                  icon: Icons.warning_amber_rounded,
                )
              else if (hasDebt)
                StockBadge(
                  label: 'مستحق السداد',
                  backgroundColor: AppColors.warningLight,
                  textColor: AppColors.warning,
                  icon: Icons.account_balance_wallet_outlined,
                )
              else
                StockBadge.matched(label: 'رصيد منتظم'),
            ],
          ),
          if (phone != null && phone!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 14,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  phone!,
                  style: AppTypography.secondary(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الرصيد القائم (المديونية):',
                    style: AppTypography.secondary(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentBalance.toStringAsFixed(2),
                        style: AppTypography.tabularNumber(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: hasDebt
                              ? (isOverLimit ? AppColors.error : AppColors.warning)
                              : AppColors.success,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onPaymentTap != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.payment_rounded, size: 16),
                      label: const Text('سند قبض'),
                      onPressed: onPaymentTap,
                    ),
                  if (onStatementTap != null) ...[
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: borderColor),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16),
                      label: const Text('كشف حساب'),
                      onPressed: onStatementTap,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
