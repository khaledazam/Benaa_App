import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptics_service.dart';
import '../../data/models/item_model.dart';
import '../providers/inventory_provider.dart';
import '../widgets/camera_scanner_dialog.dart';

import '../../core/services/pdf_report_service.dart';
import '../../core/services/barcode_label_service.dart';
import '../widgets/item_movement_dialog.dart';

class LocalStockScreen extends StatefulWidget {
  final bool showLowStockOnly;
  const LocalStockScreen({Key? key, this.showLowStockOnly = false}) : super(key: key);

  @override
  State<LocalStockScreen> createState() => _LocalStockScreenState();
}

class _LocalStockScreenState extends State<LocalStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadLocalItems();
    });
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.add_business_outlined, color: AppColors.success),
            Text(
              'تسجيل منتج جديد بالمخزن',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: barcodeController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'كود / باركود المنتَج',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              // Product Name Input with Live Autocomplete Suggestions
              Consumer<InventoryProvider>(
                builder: (context, provider, _) {
                  final allItems = provider.localItems;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RawAutocomplete<ItemModel>(
                        textEditingController: nameController,
                        focusNode: FocusNode(),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<ItemModel>.empty();
                          }
                          final query = textEditingValue.text.toLowerCase();
                          return allItems.where((ItemModel option) {
                            return option.name.toLowerCase().contains(query) ||
                                option.code.toLowerCase().contains(query);
                          });
                        },
                        displayStringForOption: (ItemModel option) => option.name,
                        onSelected: (ItemModel selection) {
                          nameController.text = selection.name;
                          barcodeController.text = selection.code;
                          categoryController.text = selection.category;
                          unitController.text = selection.unit;
                          locationController.text = selection.location ?? locationController.text;
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'اسم المنتَج / الصنف (اكتب أول حروف للتجميع والإكمال)',
                              hintText: 'مثال: بديل خشب، كورنر تيب...',
                              labelStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                              suffixIcon: const Icon(Icons.search, size: 18, color: AppColors.primaryAccent),
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topRight,
                            child: Material(
                              elevation: 6,
                              color: AppColors.getCardBg(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 180, maxWidth: 350),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primaryAccent),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderDark),
                                  itemBuilder: (BuildContext context, int index) {
                                    final ItemModel option = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        option.name,
                                        style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                                        textAlign: TextAlign.right,
                                      ),
                                      subtitle: Text(
                                        'كود: ${option.code} | الرصيد الحالي: ${option.currentStock.toInt()} ${option.unit}',
                                        style: const TextStyle(color: AppColors.success, fontSize: 11),
                                        textAlign: TextAlign.right,
                                      ),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: unitController.text.isNotEmpty ? unitController.text : 'حبة',
                      dropdownColor: AppColors.getCardBg(context),
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'وحدة القياس / التعبئة',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'حبة', child: Text('حبة / قطعة')),
                        DropdownMenuItem(value: 'متر مربع', child: Text('متر مربع (m²)')),
                        DropdownMenuItem(value: 'كرتونة', child: Text('كرتونة')),
                        DropdownMenuItem(value: 'طبلية', child: Text('طبلية / لوح')),
                        DropdownMenuItem(value: 'كيس', child: Text('كيس / شيكارة')),
                        DropdownMenuItem(value: 'طن', child: Text('طن')),
                        DropdownMenuItem(value: 'كجم', child: Text('كجم')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          unitController.text = val;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: categoryController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'التصنيف',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
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
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'الرصيد الأولي',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: locationController,
                      style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'الممر والرف بالمستودع',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
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
                    content: Text('تم إضافة/تحديث رصيد الصنف (${nameController.text.trim()}) بنجاح في المستودع! 📦'),
                  ),
                );
              }
            },
            child: const Text('إضافة للمخزن'),
          ),
        ],
      ),
    );
  }

  void _showAdjustStockDialog(BuildContext context, ItemModel item) {
    final stockController = TextEditingController(text: item.currentStock.toString());
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.edit_note, color: AppColors.warning),
            Text(
              'تعديل رصيد المخزون (${item.code})',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.name,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 28),
                  onPressed: () {
                    final cur = double.tryParse(stockController.text) ?? 0.0;
                    if (cur > 0) {
                      stockController.text = (cur - 1).toString();
                    }
                  },
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: stockController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الجديد',
                      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.success, size: 28),
                  onPressed: () {
                    final cur = double.tryParse(stockController.text) ?? 0.0;
                    stockController.text = (cur + 1).toString();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'سبب التعديل / ملاحظات',
                labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () async {
              final newStock = double.tryParse(stockController.text) ?? item.currentStock;
              final provider = Provider.of<InventoryProvider>(context, listen: false);
              await provider.adjustItemStockDirectly(item.code, newStock, noteController.text.trim());
              await HapticsService.actionSuccess();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.success,
                    content: Text('تم تعديل رصيد صنف (${item.name}) إلى $newStock بنجاح!'),
                  ),
                );
              }
            },
            child: const Text('تعديل وتحديث الرصيد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBg(context),
      appBar: AppBar(
        title: Text(widget.showLowStockOnly ? '⚠️ أصناف وشيكة النفاذ (بريدة)' : 'رصيد مستودع بريدة (القصيم)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppColors.primaryAccent),
            tooltip: 'تصدير تقرير الجرد (PDF / Excel)',
            onPressed: () async {
              final provider = Provider.of<InventoryProvider>(context, listen: false);
              final lowStockCount = provider.localItems.where((i) => i.currentStock <= 15.0).length;
              final valuation = provider.localItems.fold<double>(0.0, (sum, i) => sum + (i.currentStock * 50.0));
              await PdfReportService.printOrPreviewReport(
                items: provider.localItems,
                totalValuation: valuation,
                lowStockCount: lowStockCount,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.success),
            tooltip: 'إضافة منتج جديد للمخزن',
            onPressed: () => _showAddNewItemDialog(context),
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          var baseItems = widget.showLowStockOnly
              ? provider.localItems.where((i) => i.currentStock <= 15.0).toList()
              : provider.localItems;

          final items = _query.isEmpty
              ? baseItems
              : baseItems.where((i) {
                  final q = _query.toLowerCase();
                  return i.code.toLowerCase().contains(q) ||
                      i.name.toLowerCase().contains(q) ||
                      i.category.toLowerCase().contains(q);
                }).toList();

          return Column(
            children: [
              if (widget.showLowStockOnly)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.danger.withOpacity(0.15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'عدد الأصناف وشيكة النفاذ: ${items.length}',
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Text(
                        '⚠️ الرصيد المتبقي أقل من 15 حبة',
                        style: TextStyle(color: AppColors.danger, fontSize: 11),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val),
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن صنف بالأسم، التصنيف، أو الكود',
                    hintStyle: TextStyle(color: AppColors.getTextSecondary(context)),
                    prefixIcon: Icon(Icons.search, color: AppColors.getTextSecondary(context)),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('لا توجد أصناف بالمخزون حالياً', style: TextStyle(color: AppColors.getTextSecondary(context))))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: items.length,
                        itemBuilder: (ctx, idx) {
                          final item = items[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: AppColors.getCardBg(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: item.currentStock <= 15.0 ? AppColors.danger : AppColors.getBorder(context),
                              ),
                            ),
                            child: ListTile(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (c) => ItemMovementDialog(item: item),
                                );
                              },
                              leading: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'كود ${item.code}',
                                  style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              ),
                              subtitle: Text(
                                'الفئة: ${item.category}',
                                style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
                                textAlign: TextAlign.right,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.qr_code, color: AppColors.info, size: 20),
                                    tooltip: 'طباعة ستيكر الباركود الحراري',
                                    onPressed: () async {
                                      await BarcodeLabelService.printThermalStickerLabel(item: item);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.history, color: AppColors.primaryAccent, size: 20),
                                    tooltip: 'سجل حركة الصنف التفصيلي',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (c) => ItemMovementDialog(item: item),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: AppColors.warning, size: 22),
                                    tooltip: 'تعديل المخزون المباشر',
                                    onPressed: () => _showAdjustStockDialog(context, item),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.currentStock.toInt()} ${item.unit}',
                                        style: TextStyle(
                                          color: item.currentStock > 15.0 ? AppColors.success : AppColors.danger,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Text('الرصيد', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.success,
        icon: const Icon(Icons.add_box, color: Colors.white),
        label: const Text('إضافة منتج للمخزن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddNewItemDialog(context),
      ),
    );
  }
}
