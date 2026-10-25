import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';
import 'stock_badge.dart';

/// Professional High-Density Warehouse Product List Tile for Benaa ERP
/// Supports Cross-Warehouse Stock Discovery & Transfer Requests
class ProductListTile extends StatelessWidget {
  final String itemCode;
  final String itemName;
  final String? category;
  final String? warehouseName;
  final double currentStock;
  final String primaryUnit;
  final double minLimit;
  final String? crossWarehouseDiscoveryMessage;
  final VoidCallback? onTap;
  final VoidCallback? onQuickAction;
  final VoidCallback? onRequestTransfer;

  const ProductListTile({
    Key? key,
    required this.itemCode,
    required this.itemName,
    required this.currentStock,
    required this.primaryUnit,
    this.category,
    this.warehouseName,
    this.minLimit = 10,
    this.crossWarehouseDiscoveryMessage,
    this.onTap,
    this.onQuickAction,
    this.onRequestTransfer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);

    final isOutOfStock = currentStock <= 0;
    final isLowStock = currentStock > 0 && currentStock <= minLimit;

    Widget statusBadge;
    if (isOutOfStock) {
      statusBadge = StockBadge.outOfStock();
    } else if (isLowStock) {
      statusBadge = StockBadge.lowStock();
    } else {
      statusBadge = StockBadge.inStock();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Leading SKU Icon Box
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 22,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Center Information
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  itemName,
                                  style: AppTypography.cardTitle(
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ).copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              statusBadge,
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    itemCode,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.smallLabel(
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    ).copyWith(letterSpacing: 0.2),
                                  ),
                                ),
                              ),
                              if (warehouseName != null && warehouseName!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.warehouse_outlined,
                                  size: 14,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    warehouseName!,
                                    style: AppTypography.secondary(
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Trailing Balance & Unit
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentStock % 1 == 0
                              ? currentStock.toInt().toString()
                              : currentStock.toStringAsFixed(1),
                          style: AppTypography.tabularNumber(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isOutOfStock
                                ? AppColors.error
                                : (isLowStock
                                    ? AppColors.warning
                                    : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          primaryUnit,
                          style: AppTypography.smallLabel(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Cross-Warehouse Stock Discovery Banner (if out of stock or low stock in this warehouse)
                if (crossWarehouseDiscoveryMessage != null && crossWarehouseDiscoveryMessage!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onRequestTransfer,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF422006) : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF9A3412) : const Color(0xFFFDBA74),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.share_location_rounded, size: 16, color: Color(0xFFEA580C)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              crossWarehouseDiscoveryMessage!,
                              style: AppTypography.smallLabel(
                                color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412),
                              ).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'طلب تحويل ⇄',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
