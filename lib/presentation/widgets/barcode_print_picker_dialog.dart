import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/item_model.dart';
import '../../core/services/barcode_label_service.dart';

class BarcodePrintPickerDialog extends StatefulWidget {
  final List<ItemModel> items;

  const BarcodePrintPickerDialog({Key? key, required this.items}) : super(key: key);

  @override
  State<BarcodePrintPickerDialog> createState() => _BarcodePrintPickerDialogState();
}

class _BarcodePrintPickerDialogState extends State<BarcodePrintPickerDialog> {
  ItemModel? _selectedItem;
  int _copies = 1;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) {
      _selectedItem = widget.items.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _searchQuery.isEmpty
        ? widget.items
        : widget.items.where((i) {
            final q = _searchQuery.toLowerCase();
            return i.name.toLowerCase().contains(q) ||
                i.code.toLowerCase().contains(q) ||
                i.category.toLowerCase().contains(q);
          }).toList();

    return Dialog(
      backgroundColor: AppColors.getCardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.info, width: 1.5),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.qr_code_2, color: AppColors.info, size: 28),
                Text(
                  '🏷️ طباعة ملصق باركود حراري (Sticker)',
                  style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.getTextSecondary(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const Divider(color: AppColors.borderDark, height: 16),

            // Item Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: AppColors.getTextPrimary(context)),
              decoration: InputDecoration(
                hintText: 'ابحث عن صنف للطباعة بالأسم أو الكود...',
                hintStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: AppColors.info),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'اختر الصنف المراد طباعته:',
              style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: filteredItems.isEmpty
                  ? Center(child: Text('لا توجد أصناف بالمخزون', style: TextStyle(color: AppColors.getTextSecondary(context))))
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (ctx, idx) {
                        final item = filteredItems[idx];
                        final isSelected = _selectedItem?.code == item.code;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.info.withOpacity(0.15)
                                : AppColors.getBg(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.info : AppColors.getBorder(context),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => setState(() => _selectedItem = item),
                            leading: Radio<String>(
                              value: item.code,
                              groupValue: _selectedItem?.code,
                              activeColor: AppColors.info,
                              onChanged: (val) => setState(() => _selectedItem = item),
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 14),
                              textAlign: TextAlign.right,
                            ),
                            subtitle: Text(
                              'كود: ${item.code} | الفئة: ${item.category}',
                              style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // Sticker Copies Counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                      onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                    ),
                    Text(
                      '$_copies ملصق',
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                      onPressed: () => setState(() => _copies++),
                    ),
                  ],
                ),
                Text(
                  'عدد الملصقات المطلوب طباعتها:',
                  style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Print Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print, size: 20),
                label: Text('معاينة وطباعة الملصق الحراري ($_copies ملصق)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _selectedItem == null
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await BarcodeLabelService.printThermalStickerLabel(
                          item: _selectedItem!,
                          copies: _copies,
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
