import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';

/// Reusable Stock & Status Badges for Benaa Enterprise ERP
class StockBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StockBadge({
    Key? key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  }) : super(key: key);

  /// Status: In Stock (متوفر)
  factory StockBadge.inStock({String label = 'متوفر'}) {
    return StockBadge(
      label: label,
      backgroundColor: AppColors.successLight,
      textColor: AppColors.success,
      icon: Icons.check_circle_outline,
    );
  }

  /// Status: Low Stock (منخفض)
  factory StockBadge.lowStock({String label = 'مخزون منخفض'}) {
    return StockBadge(
      label: label,
      backgroundColor: AppColors.warningLight,
      textColor: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    );
  }

  /// Status: Out of Stock (نفذ)
  factory StockBadge.outOfStock({String label = 'نفذ المخزون'}) {
    return StockBadge(
      label: label,
      backgroundColor: AppColors.errorLight,
      textColor: AppColors.error,
      icon: Icons.error_outline_rounded,
    );
  }

  /// Status: Audited / Matched (مطابق)
  factory StockBadge.matched({String label = 'مطابق للجرد'}) {
    return StockBadge(
      label: label,
      backgroundColor: AppColors.successLight,
      textColor: AppColors.success,
      icon: Icons.verified_outlined,
    );
  }

  /// Status: Discrepancy (فارق جرد)
  factory StockBadge.discrepancy({String label = 'يوجد فارق'}) {
    return StockBadge(
      label: label,
      backgroundColor: AppColors.errorLight,
      textColor: AppColors.error,
      icon: Icons.difference_outlined,
    );
  }

  /// Status: Pending Audit (بانتظار التدقيق)
  factory StockBadge.pending({String label = 'قيد الانتظار'}) {
    return StockBadge(
      label: label,
      backgroundColor: const Color(0xFFF1F5F9),
      textColor: AppColors.textSecondary,
      icon: Icons.schedule_rounded,
    );
  }

  /// Generic Custom Badge
  factory StockBadge.neutral({required String label, IconData? icon}) {
    return StockBadge(
      label: label,
      backgroundColor: const Color(0xFFF1F5F9),
      textColor: AppColors.textPrimary,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.smallLabel(color: textColor),
          ),
        ],
      ),
    );
  }
}
