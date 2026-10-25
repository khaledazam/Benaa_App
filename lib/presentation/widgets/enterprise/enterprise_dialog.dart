import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';
import 'enterprise_button.dart';

/// Standard Enterprise Modal / Confirmation Dialog Container
class EnterpriseDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final String cancelLabel;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool isLoading;
  final IconData? icon;

  const EnterpriseDialog({
    Key? key,
    required this.title,
    required this.content,
    this.confirmLabel = 'تأكيد',
    this.onConfirm,
    this.cancelLabel = 'إلغاء',
    this.onCancel,
    this.isDestructive = false,
    this.isLoading = false,
    this.icon,
  }) : super(key: key);

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => EnterpriseDialog(
        title: title,
        icon: icon,
        isDestructive: isDestructive,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
        content: Text(
          message,
          style: AppTypography.body(color: AppColors.getTextSecondary(ctx)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Dialog(
      backgroundColor: bg,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isDestructive ? AppColors.error : AppColors.primary).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isDestructive ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.sectionHeading(
                        color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: content,
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: EnterpriseButton.secondary(
                      label: cancelLabel,
                      onPressed: onCancel ?? () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: isDestructive
                        ? EnterpriseButton.danger(
                            label: confirmLabel,
                            isLoading: isLoading,
                            onPressed: onConfirm,
                          )
                        : EnterpriseButton.primary(
                            label: confirmLabel,
                            isLoading: isLoading,
                            onPressed: onConfirm,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
