import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';

/// Enterprise Search Input with Integrated Barcode/QR Scanner Action
class EnterpriseSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onScanPressed;
  final String hintText;
  final FocusNode? focusNode;

  const EnterpriseSearchField({
    Key? key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.onScanPressed,
    this.hintText = 'بحث برقم الصنف أو الاسم أو الباركود...',
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: AppTypography.body(
          color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          filled: false,
          hintText: hintText,
          hintStyle: AppTypography.body(
            color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  onPressed: () {
                    controller.clear();
                    if (onClear != null) onClear!();
                    if (onChanged != null) onChanged!('');
                  },
                ),
              if (onScanPressed != null)
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  tooltip: 'مسح الباركود',
                  onPressed: onScanPressed,
                ),
            ],
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
