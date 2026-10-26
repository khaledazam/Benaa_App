import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/haptics_service.dart';
import '../../data/models/item_model.dart';
import '../providers/inventory_provider.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../widgets/item_movement_dialog.dart';
import '../../core/services/barcode_label_service.dart';
import '../widgets/enterprise/product_list_tile.dart';
import '../widgets/enterprise/enterprise_search_field.dart';
import '../widgets/enterprise/enterprise_button.dart';
import '../widgets/enterprise/enterprise_dialog.dart';
import '../widgets/enterprise/enterprise_empty_state.dart';
import '../../core/services/benaa_warehouse_service.dart';
import '../../core/services/cloud_auth_service.dart';

/// Professional High-Density Warehouse Inventory Screen for Benaa
class LocalStockScreen extends StatefulWidget {
  final bool showLowStockOnly;
  const LocalStockScreen({Key? key, this.showLowStockOnly = false}) : super(key: key);

  @override
  State<LocalStockScreen> createState() => _LocalStockScreenState();
}

class _LocalStockScreenState extends State<LocalStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late bool _filterLowStock;
  String _selectedCategory = 'الكل';
  final Map<String, CrossWarehouseResult?> _crossWarehouseMap = {};
  final Set<String> _pendingLookups = {};

  @override
  void initState() {
    super.initState();
    _filterLowStock = widget.showLowStockOnly;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadLocalItems();
    });
  }

  void _checkCrossWarehouse(ItemModel item) {
    if (_crossWarehouseMap.containsKey(item.code) || _pendingLookups.contains(item.code)) return;
    _pendingLookups.add(item.code);

    BenaaWarehouseService.discoverCrossWarehouseStock(
      skuOrProductId: item.code,
    ).then((result) {
      if (mounted) {
        setState(() {
          _crossWarehouseMap[item.code] = result;
          _pendingLookups.remove(item.code);
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _pendingLookups.remove(item.code);
        });
      }
    });
  }

  void _showRequestTransferDialog(BuildContext context, ItemModel item, CrossWarehouseResult crossRes) {
    final best = crossRes.bestMatch;
    if (best == null || best.available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد كميات متاحة للتحويل في المستودعات الأخرى')),
      );
      return;
    }

    final qtyController = TextEditingController(text: '10');
    final notesController = TextEditingController(text: 'طلب تحويل عاجل لسد عجز المخزن');
    final user = CloudAuthService.currentUser;
    final targetWhId = user?.primaryWarehouseId ?? '6a7f78f2e720fc52f142e03e';

    showDialog(
      context: context,
      builder: (ctx) => EnterpriseDialog(
        title: 'طلب تحويل مخزني بين المستودعات',
        icon: Icons.swap_horiz_rounded,
        confirmLabel: 'إرسال طلب التحويل للمشرف',
        onConfirm: () async {
          final qty = double.tryParse(qtyController.text) ?? 0;
          if (qty <= 0 || qty > best.available) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                content: Text('يرجى إدخال كمية صحيحة بين 1 و ${best.available.toInt()}'),
              ),
            );
            return;
          }

          final res = await BenaaWarehouseService.requestTransfer(
            productId: crossRes.productId.isNotEmpty ? crossRes.productId : item.code,
            fromWarehouseId: best.warehouseId,
            toWarehouseId: targetWhId,
            quantity: qty,
            notes: notesController.text.trim(),
          );

          await HapticsService.actionSuccess();

          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text('تم إرسال طلب تحويل ($qty ${item.unit}) من ${best.warehouseName} بنجاح!'),
              ),
            );
          }
        },
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppTypography.cardTitle()),
                  const SizedBox(height: 4),
                  Text('كود الصنف: ${item.code}', style: AppTypography.smallLabel(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          crossRes.discoveryMessage,
                          style: AppTypography.smallLabel(color: AppColors.success).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('من مستودع (المصدر):', style: AppTypography.smallLabel(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(best.warehouseName, style: AppTypography.body()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إلى مستودع (الوجهة):', style: AppTypography.smallLabel(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(user?.primaryWarehouseName ?? 'مستودعك الحالي', style: AppTypography.body()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'الكمية المطلوبة للتحويل (${item.unit})',
                helperText: 'الحد الأقصى المتاح حالياً: ${best.available.toInt()} ${item.unit}',
                prefixIcon: const Icon(Icons.format_list_numbered_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات وتوجيهات التحويل',
                prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemOptions(BuildContext context, ItemModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppTypography.cardTitle(
                          color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'كود: ${item.code} | الرصيد الحالي: ${item.currentStock % 1 == 0 ? item.currentStock.toInt() : item.currentStock} ${item.unit}',
                        style: AppTypography.secondary(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, size: 20),
                  title: const Text('تعديل الرصيد الفعلي'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAdjustStockDialog(context, item);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history_rounded, size: 20),
                  title: const Text('سجل حركات الصنف (كارت الصنف)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => ItemMovementDialog(item: item),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.print_outlined, size: 20),
                  title: const Text('طباعة ملصق الباركود'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await BarcodeLabelService.printThermalStickerLabel(
                      item: item,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  title: const Text('حذف الصنف من المستودع', style: TextStyle(color: AppColors.error)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await EnterpriseDialog.showConfirmation(
                      context: context,
                      title: 'تأكيد حذف الصنف',
                      message: 'هل أنت متأكد من حذف الصنف (${item.name}) نهائياً من المستودع؟',
                      confirmLabel: 'حذف نهائي',
                      isDestructive: true,
                      icon: Icons.delete_outline_rounded,
                    );
                    if (confirm == true && mounted) {
                      await Provider.of<InventoryProvider>(context, listen: false).deleteItem(item.code);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text('تم حذف الصنف بنجاح'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddNewItemDialog(BuildContext context, {String initialBarcode = ''}) {
    final barcodeController = TextEditingController(text: initialBarcode);
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final unitController = TextEditingController(text: 'حبة');
    final qtyController = TextEditingController();
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => EnterpriseDialog(
        title: 'تسجيل منتج جديد بالمستودع',
        icon: Icons.add_business_outlined,
        confirmLabel: 'إضافة للمخزن',
        onConfirm: () async {
          if (nameController.text.trim().isEmpty) return;
          final provider = Provider.of<InventoryProvider>(context, listen: false);
          await provider.registerNewScannedItem(
            barcode: barcodeController.text.trim(),
            itemName: nameController.text.trim(),
            category: categoryController.text.trim(),
            unit: unitController.text.trim(),
            initialQty: double.tryParse(qtyController.text) ?? 0.0,
            location: locationController.text.trim(),
          );
          await HapticsService.actionSuccess();
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text('تمت إضافة الصنف (${nameController.text.trim()}) بنجاح!'),
              ),
            );
          }
        },
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: barcodeController,
              decoration: const InputDecoration(labelText: 'كود / باركود الصنف'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الصنف التجاري',
                hintText: 'مثال: بديل خشب، زاوية جدار 3م...',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: unitController.text,
                    decoration: const InputDecoration(labelText: 'الوحدة'),
                    items: const [
                      DropdownMenuItem(value: 'حبة', child: Text('حبة / قطعة')),
                      DropdownMenuItem(value: 'لوح', child: Text('لوح')),
                      DropdownMenuItem(value: 'متر مربع', child: Text('متر مربع (m²)')),
                      DropdownMenuItem(value: 'كرتونة', child: Text('كرتونة')),
                      DropdownMenuItem(value: 'طبلية', child: Text('طبلية')),
                      DropdownMenuItem(value: 'كيس', child: Text('كيس')),
                    ],
                    onChanged: (val) {
                      if (val != null) unitController.text = val;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'التصنيف'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'الممر والرف'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustStockDialog(BuildContext context, ItemModel item) {
    final stockController = TextEditingController(text: item.currentStock.toString());
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => EnterpriseDialog(
        title: 'تعديل رصيد المخزون',
        icon: Icons.edit_note_rounded,
        confirmLabel: 'حفظ التعديل',
        onConfirm: () async {
          final newStock = double.tryParse(stockController.text) ?? item.currentStock;
          final provider = Provider.of<InventoryProvider>(context, listen: false);
          await provider.adjustItemStockDirectly(
            item.code,
            newStock,
            noteController.text.trim().isNotEmpty ? noteController.text.trim() : 'تعديل رصيد يدوي',
          );
          await HapticsService.actionSuccess();
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text('تم تعديل رصيد (${item.name}) إلى $newStock ${item.unit}'),
              ),
            );
          }
        },
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: AppTypography.cardTitle(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: stockController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTypography.tabularNumber(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'الرصيد الفعلي الجديد (${item.unit})',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'سبب التعديل / ملاحظات الجرد',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المخزون والأصناف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: 'إضافة صنف جديد',
            onPressed: () => _showAddNewItemDialog(context),
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final allItems = provider.localItems;
          final lowStockCount = allItems.where((i) => i.currentStock <= 15).length;
          final totalValuation = allItems.fold<double>(0.0, (sum, i) => sum + (i.currentStock * i.unitPrice));

          // Extract distinct categories
          final categories = <String>['الكل'];
          for (var item in allItems) {
            if (item.category.isNotEmpty && !categories.contains(item.category)) {
              categories.add(item.category);
            }
          }

          final filtered = allItems.where((item) {
            final matchesQuery = _query.isEmpty ||
                item.name.toLowerCase().contains(_query.toLowerCase()) ||
                item.code.toLowerCase().contains(_query.toLowerCase()) ||
                item.category.toLowerCase().contains(_query.toLowerCase());

            final matchesCategory = _selectedCategory == 'الكل' || item.category == _selectedCategory;

            if (_filterLowStock) {
              return matchesQuery && matchesCategory && (item.currentStock <= 15.0);
            }
            return matchesQuery && matchesCategory;
          }).toList();

          return Column(
            children: [
              // 1. Top Metrics Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${allItems.length} صنف مسجل',
                            style: AppTypography.smallLabel(color: AppColors.primary).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${totalValuation.toStringAsFixed(0)} ر.س',
                          style: AppTypography.tabularNumber(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _filterLowStock = !_filterLowStock;
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _filterLowStock
                              ? AppColors.error
                              : AppColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: _filterLowStock ? Colors.white : AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'وشيك النفاذ ($lowStockCount)',
                              style: AppTypography.smallLabel(
                                color: _filterLowStock ? Colors.white : AppColors.error,
                              ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Search & Category Bar
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    EnterpriseSearchField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _query = val.trim()),
                      onScanPressed: () async {
                        final code = await showDialog<String>(
                          context: context,
                          builder: (_) => const CameraScannerDialog(),
                        );
                        if (code != null && code.isNotEmpty) {
                          _searchController.text = code;
                          setState(() => _query = code.trim());
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    // Category Chips Scroll
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, idx) {
                          final cat = categories[idx];
                          final isSelected = _selectedCategory == cat;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = cat;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? AppColors.borderDark : const Color(0xFFCBD5E1)),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  cat,
                                  style: AppTypography.smallLabel(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                  ).copyWith(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Products List
              Expanded(
                child: filtered.isEmpty
                    ? EnterpriseEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: _query.isNotEmpty || _selectedCategory != 'الكل'
                            ? 'لا توجد نتائج مطابقة لبحثك'
                            : 'لا توجد أصناف مسجلة في المستودع',
                        message: _query.isNotEmpty || _selectedCategory != 'الكل'
                            ? 'جرب البحث برقم أو كود صنف آخر أو اختر تصنيفاً مختلفاً'
                            : 'يمكنك البدء بإضافة أصناف جديدة أو تحميل البيانات التجريبية للاختبار',
                        actionLabel: _query.isNotEmpty || _selectedCategory != 'الكل'
                            ? 'مسح الفلاتر'
                            : 'إضافة صنف جديد',
                        onAction: () {
                          if (_query.isNotEmpty || _selectedCategory != 'الكل' || _filterLowStock) {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _selectedCategory = 'الكل';
                              _filterLowStock = false;
                            });
                          } else {
                            _showAddNewItemDialog(context);
                          }
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: () async => await provider.loadLocalItems(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            if (item.currentStock <= 0) {
                              _checkCrossWarehouse(item);
                            }
                            final crossRes = _crossWarehouseMap[item.code];

                            return ProductListTile(
                              itemCode: item.code,
                              itemName: item.name,
                              category: item.category,
                              warehouseName: item.location,
                              currentStock: item.currentStock,
                              primaryUnit: item.unit,
                              crossWarehouseDiscoveryMessage: crossRes?.discoveryMessage,
                              onRequestTransfer: crossRes != null && crossRes.bestMatch != null
                                  ? () => _showRequestTransferDialog(context, item, crossRes)
                                  : null,
                              onTap: () => _showItemOptions(context, item),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
