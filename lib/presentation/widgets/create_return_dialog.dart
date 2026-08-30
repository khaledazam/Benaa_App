import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/item_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../data/models/return_invoice_model.dart';
import '../../core/services/unit_conversion_engine.dart';
import '../../core/services/haptics_service.dart';
import '../../data/models/customer_model.dart';
import '../widgets/customer_autocomplete_field.dart';
import '../providers/inventory_provider.dart';

class CreateReturnDialog extends StatefulWidget {
  const CreateReturnDialog({Key? key}) : super(key: key);

  @override
  State<CreateReturnDialog> createState() => _CreateReturnDialogState();
}

class _CreateReturnDialogState extends State<CreateReturnDialog> {
  ReturnType _returnType = ReturnType.salesReturn;
  final TextEditingController _partyNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _refundMethod = 'خصم وتخفيض رصيد الحساب';

  ItemModel? _selectedItem;
  ProductUnitModel? _selectedUnit;
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  final List<ReturnItemModel> _returnItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadLocalItems();
    });
  }

  void _addItemToReturnList() {
    if (_selectedItem == null) return;
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final unitName = _selectedUnit?.unitName ?? _selectedItem!.unit;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال كمية صحيحة أكبر من 0')),
      );
      return;
    }

    final baseQty = UnitConversionEngine.convertToBaseUnit(
      item: _selectedItem!,
      unitName: unitName,
      quantity: qty,
    );

    setState(() {
      _returnItems.add(ReturnItemModel(
        itemCode: _selectedItem!.code,
        itemName: _selectedItem!.name,
        returnedQty: qty,
        unit: unitName,
        baseQty: baseQty,
        unitPrice: price,
        reason: _reasonController.text.trim(),
      ));

      _selectedItem = null;
      _selectedUnit = null;
      _qtyController.text = '1';
      _priceController.clear();
    });

    HapticsService.scanSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);

    return Dialog(
      backgroundColor: AppColors.getCardBg(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 580,
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
                          '↩️ إنشاء فاتورة مرتجع جديدة',
                          style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'مرتجع مبيعات عميل (زيادة المخزون) أو مرتجع توريد مورد (تخفيض المخزون)',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.assignment_return_outlined, color: AppColors.danger, size: 28),
                  ],
                ),
              ],
            ),

            const Divider(color: AppColors.borderDark, height: 16),

            // Main Settings Form
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Return Type Segmented Selector
                    const Text('نوع فاتورة المرتجع:', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() {
                              _returnType = ReturnType.purchaseReturn;
                              _partyNameController.text = 'مورد المواد (الشركة المصنعة)';
                            }),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _returnType == ReturnType.purchaseReturn ? AppColors.danger : AppColors.getBg(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.danger),
                              ),
                              child: Center(
                                child: Text(
                                  '📤 مرتجع توريد إلى مورد',
                                  style: TextStyle(
                                    color: _returnType == ReturnType.purchaseReturn ? Colors.white : AppColors.getTextPrimary(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() {
                              _returnType = ReturnType.salesReturn;
                              _partyNameController.text = 'عميل عام';
                            }),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _returnType == ReturnType.salesReturn ? AppColors.success : AppColors.getBg(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.success),
                              ),
                              child: Center(
                                child: Text(
                                  '📥 مرتجع مبيعات من عميل',
                                  style: TextStyle(
                                    color: _returnType == ReturnType.salesReturn ? Colors.white : AppColors.getTextPrimary(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Party Name & Refund Method
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('طريقة التسوية والرد', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _refundMethod,
                                dropdownColor: AppColors.getCardBg(context),
                                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12),
                                items: const [
                                  DropdownMenuItem(value: 'خصم وتخفيض رصيد الحساب', child: Text('خصم وتخفيض الحساب / كشف العميل')),
                                  DropdownMenuItem(value: 'سداد نقدي Cash', child: Text('سداد نقدي Cash')),
                                  DropdownMenuItem(value: 'تحويل بنكي', child: Text('تحويل بنكي')),
                                ],
                                onChanged: (v) => setState(() => _refundMethod = v!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_returnType == ReturnType.salesReturn ? 'اسم العميل المرتجِع (اكتب للاقتراح المباشر)' : 'اسم المورد', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                              const SizedBox(height: 4),
                              if (_returnType == ReturnType.salesReturn)
                                CustomerAutocompleteField(
                                  controller: _partyNameController,
                                  labelText: 'اكتب أول حروف من اسم العميل...',
                                  onCustomerSelected: (c) {
                                    setState(() {
                                      _partyNameController.text = c.name;
                                    });
                                  },
                                )
                              else
                                TextField(
                                  controller: _partyNameController,
                                  style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(hintText: 'اسم المورد أو الشركة المصنعة...'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Item Selection & Multi-Unit Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.getBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.getBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('إصدار وإضافة صنف للمرتجع (اكتب أول حروف للاقتراح الفوري):', style: TextStyle(color: AppColors.info, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          RawAutocomplete<ItemModel>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return provider.localItems;
                              }
                              final query = textEditingValue.text.toLowerCase();
                              return provider.localItems.where((ItemModel item) {
                                return item.name.toLowerCase().contains(query) ||
                                    item.code.toLowerCase().contains(query) ||
                                    item.category.toLowerCase().contains(query);
                              });
                            },
                            displayStringForOption: (ItemModel option) => '${option.name} (${option.code})',
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: '🔍 اكتب أول حروف من اسم المنتج أو الباركود للاقتراح...',
                                  hintStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
                                  prefixIcon: const Icon(Icons.search, color: AppColors.info),
                                  suffixIcon: controller.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                                          onPressed: () {
                                            controller.clear();
                                            setState(() {
                                              _selectedItem = null;
                                              _selectedUnit = null;
                                            });
                                          },
                                        )
                                      : null,
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topRight,
                                child: Material(
                                  elevation: 6,
                                  color: AppColors.getCardBg(context),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 480,
                                    constraints: const BoxConstraints(maxHeight: 220),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.info),
                                    ),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (BuildContext context, int index) {
                                        final ItemModel option = options.elementAt(index);
                                        return ListTile(
                                          title: Text(
                                            option.name,
                                            style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          subtitle: Text(
                                            'كود: ${option.code} | التصنيف: ${option.category} | الرصيد المتاح: ${option.currentStock.toInt()} ${option.unit}',
                                            style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                                          ),
                                          onTap: () {
                                            onSelected(option);
                                            setState(() {
                                              _selectedItem = option;
                                              _selectedUnit = option.units.firstWhere((u) => u.isBase, orElse: () => option.units.first);
                                              _priceController.text = option.unitPrice.toStringAsFixed(2);
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          if (_selectedItem != null) ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<ProductUnitModel>(
                              value: _selectedUnit ?? _selectedItem!.units.firstWhere((u) => u.isBase, orElse: () => _selectedItem!.units.first),
                              dropdownColor: AppColors.getCardBg(context),
                              style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12),
                              items: _selectedItem!.units.where((u) => u.isActive).map((u) {
                                return DropdownMenuItem(
                                  value: u,
                                  child: Text('${u.unitName} (معامل: ${u.conversionFactor} ${_selectedItem!.unit})'),
                                );
                              }).toList(),
                              onChanged: (u) {
                                if (u != null) {
                                  setState(() {
                                    _selectedUnit = u;
                                    _priceController.text = (u.salePrice ?? (_selectedItem!.unitPrice * u.conversionFactor)).toStringAsFixed(2);
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _priceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12),
                                    decoration: const InputDecoration(labelText: 'سعر الوحدة (ر.س)'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _qtyController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                                    decoration: InputDecoration(labelText: 'الكمية المرتجعة (${_selectedUnit?.unitName ?? _selectedItem!.unit})'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _reasonController,
                              style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12),
                              decoration: const InputDecoration(labelText: 'سبب الإرجاع (تالف / زيادة / تغيير رأي العميل)'),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
                              icon: const Icon(Icons.add_shopping_cart, size: 16),
                              label: const Text('إضافة الصنف لقائمة المرتجع'),
                              onPressed: _addItemToReturnList,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Added Return Items Table
                    Text(
                      'الأصناف المضافة للمرتجع (${_returnItems.length}):',
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),

                    if (_returnItems.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('لم يتم إضافة أصناف قائمة المرتجع بعد', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _returnItems.length,
                        itemBuilder: (ctx, idx) {
                          final item = _returnItems[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            color: AppColors.getBg(context),
                            child: ListTile(
                              title: Text(item.itemName, style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('الكمية: ${item.returnedQty} ${item.unit} | السبب: ${item.reason} | الإجمالي: ${item.totalPrice.toStringAsFixed(2)} ر.س', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                onPressed: () => setState(() => _returnItems.removeAt(idx)),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Submit Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المبلغ الإجمالي المرتجَع: ${_returnItems.fold<double>(0.0, (sum, i) => sum + i.totalPrice).toStringAsFixed(2)} ر.س',
                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _returnType == ReturnType.salesReturn ? AppColors.success : AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: Text(
                    _returnType == ReturnType.salesReturn ? 'حفظ ومعالجة مرتجع مبيعات 📥' : 'حفظ ومعالجة مرتجع توريد 📤',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _returnItems.isEmpty
                      ? null
                      : () async {
                          await provider.processReturnInvoice(
                            returnType: _returnType,
                            partyName: _partyNameController.text.trim(),
                            refundMethod: _refundMethod,
                            notes: _notesController.text.trim(),
                            items: _returnItems,
                          );
                          await HapticsService.actionSuccess();
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('تم إكمال وتأكيد فاتورة المرتجع وتحديث مخزون مستودع بريدة بنجاح!'),
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
