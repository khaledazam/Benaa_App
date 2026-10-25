import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';

/// Touch-Friendly Numeric Stepper & Direct Input for Warehouse Quantities
class QuantityInput extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double? max;
  final String? unit;

  const QuantityInput({
    Key? key,
    required this.value,
    required this.onChanged,
    this.step = 1.0,
    this.min = 0.0,
    this.max,
    this.unit,
  }) : super(key: key);

  void _decrement() {
    final next = (value - step).clamp(min, max ?? double.infinity);
    onChanged(double.parse(next.toStringAsFixed(2)));
  }

  void _increment() {
    final next = (value + step).clamp(min, max ?? double.infinity);
    onChanged(double.parse(next.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrement Button
          InkWell(
            onTap: value > min ? _decrement : null,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
            child: Container(
              width: 38,
              height: 42,
              alignment: Alignment.center,
              child: Icon(
                Icons.remove_rounded,
                size: 18,
                color: value > min
                    ? (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary)
                    : (isDark ? const Color(0xFF475569) : AppColors.textMuted),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: borderColor),

          // Value Display
          Container(
            constraints: const BoxConstraints(minWidth: 54),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1),
                  style: AppTypography.tabularNumber(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: AppTypography.smallLabel(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(width: 1, height: 24, color: borderColor),

          // Increment Button
          InkWell(
            onTap: (max == null || value < max!) ? _increment : null,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
            child: Container(
              width: 38,
              height: 42,
              alignment: Alignment.center,
              child: Icon(
                Icons.add_rounded,
                size: 18,
                color: (max == null || value < max!)
                    ? (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary)
                    : (isDark ? const Color(0xFF475569) : AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
