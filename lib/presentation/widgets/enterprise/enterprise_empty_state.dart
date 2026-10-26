import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';
import 'enterprise_button.dart';

/// Clean Minimalist Enterprise Empty State
class EnterpriseEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EnterpriseEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF2F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.cardTitle(
                color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTypography.secondary(
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              EnterpriseButton.primary(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      )),
    );
  }
}
