import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';

enum EnterpriseButtonVariant { primary, secondary, danger, text }

/// Standardized Enterprise Button for Benaa ERP
class EnterpriseButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final EnterpriseButtonVariant variant;
  final double? width;
  final double height;

  const EnterpriseButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = EnterpriseButtonVariant.primary,
    this.width,
    this.height = 44,
  }) : super(key: key);

  factory EnterpriseButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    double? width,
    double height = 44,
  }) {
    return EnterpriseButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      variant: EnterpriseButtonVariant.primary,
      width: width,
      height: height,
    );
  }

  factory EnterpriseButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    double? width,
    double height = 44,
  }) {
    return EnterpriseButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      variant: EnterpriseButtonVariant.secondary,
      width: width,
      height: height,
    );
  }

  factory EnterpriseButton.danger({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    double? width,
    double height = 44,
  }) {
    return EnterpriseButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      variant: EnterpriseButtonVariant.danger,
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide? border;

    switch (variant) {
      case EnterpriseButtonVariant.primary:
        bg = isDark ? AppColors.primaryLight : AppColors.primary;
        fg = Colors.white;
        border = BorderSide.none;
        break;
      case EnterpriseButtonVariant.secondary:
        bg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
        fg = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
        border = BorderSide(color: isDark ? AppColors.borderDark : AppColors.border, width: 1.2);
        break;
      case EnterpriseButtonVariant.danger:
        bg = AppColors.error;
        fg = Colors.white;
        border = BorderSide.none;
        break;
      case EnterpriseButtonVariant.text:
        bg = Colors.transparent;
        fg = isDark ? AppColors.primaryLight : AppColors.primary;
        border = BorderSide.none;
        break;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: AppTypography.bodyBold(color: fg),
        ),
      ],
    );

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: isLoading ? null : onPressed,
        child: content,
      ),
    );
  }
}
