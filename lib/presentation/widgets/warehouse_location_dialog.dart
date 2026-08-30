import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/item_model.dart';
import '../../core/services/haptics_service.dart';
import '../providers/inventory_provider.dart';

class WarehouseLocationDialog extends StatefulWidget {
  final List<ItemModel> items;

  const WarehouseLocationDialog({Key? key, required this.items}) : super(key: key);

  @override
  State<WarehouseLocationDialog> createState() => _WarehouseLocationDialogState();
}

class _WarehouseLocationDialogState extends State<WarehouseLocationDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedAisle = 'ممر A';

  final List<String> _aisles = [
    'الجميع',
    'ممر A',
    'ممر B',
    'ممر C',
    'ممر D',
    'غير محدد / جديد',
  ];

  final List<String> _racks = [
    'رف 1',
    'رف 2',
    'رف 3',
    'رف 4',
    'رف 5',
  ];

  void _showEditLocationDialog(BuildContext context, ItemModel item) {
    String currentAisle = 'ممر A';
    String currentRack = 'رف 1';
    String currentBin = 'كابينة 1';

    if (item.location.contains('ممر B')) currentAisle = 'ممر B';
    else if (item.location.contains('ممر C')) currentAisle = 'ممر C';
    else if (item.location.contains('ممر D')) currentAisle = 'ممر D';

    if (item.location.contains('رف 2')) currentRack = 'رف 2';
    else if (item.location.contains('رف 3')) currentRack = 'رف 3';
    else if (item.location.contains('رف 4')) currentRack = 'رف 4';
    else if (item.location.contains('رف 5')) currentRack = 'رف 5';

    final customLocationController = TextEditingController(text: item.location);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getCardBg(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.edit_location_alt_outlined, color: AppColors.info, size: 26),
              Text(
                '📍 تحديد موضع الصنف بالرف والممر',
                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الرصيد: ${item.currentStock.toInt()} ${item.unit}', style: const TextStyle(color: AppColors.info, fontSize: 11)),
                      Text('${item.name} (${item.code})', style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text('اختر الممر الرئيسي:', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: currentAisle,
                  dropdownColor: AppColors.getCardBg(context),
                  style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'ممر A', child: Text('ممر A — مواد البناء والأسمنت')),
                    DropdownMenuItem(value: 'ممر B', child: Text('ممر B — السيراميك والبورسلان')),
                    DropdownMenuItem(value: 'ممر C', child: Text('ممر C — الدهانات والسباكة')),
                    DropdownMenuItem(value: 'ممر D', child: Text('ممر D — الكهرباء والتجهيزات')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        currentAisle = val;
                        customLocationController.text = '$currentAisle - $currentRack - $currentBin';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('الكابينة / الخانة', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: currentBin,
                            dropdownColor: AppColors.getCardBg(context),
                            style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12),
                            items: List.generate(12, (i) => 'كابينة ${i + 1}')
                                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  currentBin = val;
                                  customLocationController.text = '$currentAisle - $currentRack - $currentBin';
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('الرف المخزني', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: currentRack,
                            dropdownColor: AppColors.getCardBg(context),
                            style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12),
                            items: const [
                              DropdownMenuItem(value: 'رف 1', child: Text('رف 1 (أرضي ثقيل)')),
                              DropdownMenuItem(value: 'رف 2', child: Text('رف 2 (أوسط 1)')),
                              DropdownMenuItem(value: 'رف 3', child: Text('رف 3 (أوسط 2)')),
                              DropdownMenuItem(value: 'رف 4', child: Text('رف 4 (علوي 1)')),
                              DropdownMenuItem(value: 'رف 5', child: Text('رف 5 (علوي 2 - خفيف)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  currentRack = val;
                                  customLocationController.text = '$currentAisle - $currentRack - $currentBin';
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text('صيغة الموضع المخصصة:', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                const SizedBox(height: 4),
                TextField(
                  controller: customLocationController,
                  style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.bold, fontSize: 13),
                  decoration: const InputDecoration(hintText: 'مثال: ممر A - رف 2 - كابينة 4'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('حفظ وتحديث الموضع آلياً'),
              onPressed: () async {
                final newLoc = customLocationController.text.trim();
                if (newLoc.isNotEmpty) {
                  await Provider.of<InventoryProvider>(context, listen: false).updateItemLocation(item.code, newLoc);
                  await HapticsService.actionSuccess();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.success, content: Text('تم نقل وتحديد موضع (${item.name}) إلى $newLoc بنجاح!')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final allItems = provider.localItems.isNotEmpty ? provider.localItems : widget.items;

        // Count unassigned/new items
        final unassignedCount = allItems.where((i) => i.location.isEmpty || i.location == 'غير محدد' || i.location == 'ممر A - رف 1').length;

        // Filter items dynamically
        final filteredItems = allItems.where((item) {
          final matchesSearch = _searchQuery.isEmpty ||
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.location.toLowerCase().contains(_searchQuery.toLowerCase());

          bool matchesAisle = true;
          if (_selectedAisle == 'غير محدد / جديد') {
            matchesAisle = item.location.isEmpty || item.location == 'غير محدد' || item.location == 'ممر A - رف 1';
          } else if (_selectedAisle != 'الجميع') {
            matchesAisle = item.location.contains(_selectedAisle);
          }

          return matchesSearch && matchesAisle;
        }).toList();

        return Dialog(
          backgroundColor: AppColors.getCardBg(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.info, width: 1.5),
          ),
          insetPadding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            height: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Dialog Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.getTextSecondary(context)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '📍 خريطة ومواضع مستودع بريدة (تفاعلية ديناميكية)',
                              style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تحديث فوري عند إضافة أي منتج جديد للمستودع',
                              style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.map_outlined, color: AppColors.info, size: 28),
                      ],
                    ),
                  ],
                ),

                const Divider(color: AppColors.borderDark, height: 16),

                // Interactive Aisle Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _aisles.map((aisle) {
                      final isSelected = _selectedAisle == aisle;
                      final isUnassignedTab = aisle == 'غير محدد / جديد';
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(() => _selectedAisle = aisle),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isUnassignedTab ? AppColors.warning : AppColors.info)
                                  : AppColors.getBg(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? (isUnassignedTab ? AppColors.warning : AppColors.info)
                                    : AppColors.getBorder(context),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (isUnassignedTab && unassignedCount > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : AppColors.warning,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$unassignedCount',
                                      style: TextStyle(
                                        color: isSelected ? AppColors.warning : Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  aisle,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.getTextSecondary(context),
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المنتج، الكود، الرف، أو الممر...',
                    hintStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: AppColors.info),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 10),

                // Live Status Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '💡 انقر على أي صنف لتحديد أو تغيير موضعه فوراً',
                      style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'الأصناف المعروضة (${filteredItems.length} صنف)',
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Dynamic Interactive Floor Map & Items List
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_off_outlined, color: AppColors.textSecondary, size: 42),
                              const SizedBox(height: 8),
                              Text('لا توجد أصناف في هذا القطاع حالياً', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (ctx, idx) {
                            final item = filteredItems[idx];
                            final isUnassigned = item.location.isEmpty || item.location == 'غير محدد' || item.location == 'ممر A - رف 1';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: AppColors.getBg(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isUnassigned ? AppColors.warning.withOpacity(0.5) : AppColors.getBorder(context),
                                  width: isUnassigned ? 1.5 : 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _showEditLocationDialog(context, item),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Location Badge Button
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isUnassigned ? AppColors.warning : AppColors.info,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.edit_location_alt_outlined, color: Colors.white, size: 16),
                                        label: Text(
                                          isUnassigned ? 'تحديد الموضع 📍' : item.location,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                        onPressed: () => _showEditLocationDialog(context, item),
                                      ),
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            children: [
                                              if (isUnassigned) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.warning.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text('جديد / غير محدد', style: TextStyle(color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Text(
                                                item.name,
                                                style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'كود: ${item.code} | التصنيف: ${item.category} | الرصيد: ${item.currentStock.toInt()} ${item.unit}',
                                            style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
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
        );
      },
    );
  }
}
