import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/item_model.dart';

class PackagingUnitConverterDialog extends StatefulWidget {
  final List<ItemModel> items;

  const PackagingUnitConverterDialog({Key? key, required this.items}) : super(key: key);

  @override
  State<PackagingUnitConverterDialog> createState() => _PackagingUnitConverterDialogState();
}

class _PackagingUnitConverterDialogState extends State<PackagingUnitConverterDialog> {
  ItemModel? _selectedItem;
  final TextEditingController _largeQtyController = TextEditingController();
  final TextEditingController _packagingUnitController = TextEditingController(text: 'كرتونة');
  final TextEditingController _conversionFactorController = TextEditingController();
  final TextEditingController _baseUnitController = TextEditingController(text: 'حبة');

  double _calculatedBaseQty = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) {
      _selectedItem = widget.items.first;
      _loadItemDefaults(_selectedItem!);
    }
  }

  void _loadItemDefaults(ItemModel item) {
    _packagingUnitController.text = item.packagingUnit ?? 'كرتونة';
    _conversionFactorController.text = item.conversionFactor.toStringAsFixed(0);
    _baseUnitController.text = item.unit;
    _updateConversion();
  }

  void _updateConversion() {
    final largeQty = double.tryParse(_largeQtyController.text) ?? 0.0;
    final factor = double.tryParse(_conversionFactorController.text) ?? 1.0;
    setState(() {
      _calculatedBaseQty = largeQty * factor;
    });
  }

  @override
  void dispose() {
    _largeQtyController.dispose();
    _packagingUnitController.dispose();
    _conversionFactorController.dispose();
    _baseUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentFactor = double.tryParse(_conversionFactorController.text) ?? 1.0;

    return Dialog(
      backgroundColor: AppColors.getCardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.warning, width: 1.5),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 550,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.calculate_outlined, color: AppColors.warning, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📦 حاسبة ومحول التعبئة والوحدات',
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 15, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.getTextSecondary(context)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const Divider(color: AppColors.borderDark, height: 16),

              Text(
                'اختر الصنف المراد تحويل وحداته:',
                style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<ItemModel>(
                initialValue: _selectedItem,
                isExpanded: true,
                dropdownColor: AppColors.getCardBg(context),
                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 14),
                items: widget.items.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(
                      '${item.name} (${item.code})',
                      style: TextStyle(color: AppColors.getTextPrimary(context)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedItem = val;
                      _loadItemDefaults(val);
                    });
                  }
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.inventory_2_outlined, color: AppColors.warning),
                ),
              ),

              const SizedBox(height: 14),

              // Manual Customization Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.getBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.getBorder(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit, color: AppColors.warning, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'تخصيص أسماء ومعامل التحويل:',
                            style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('الوحدة الكبرى', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _packagingUnitController,
                                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12, fontWeight: FontWeight.bold),
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(hintText: 'طبلية/كرتونة'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('معامل التحويل', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _conversionFactorController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold),
                                onChanged: (_) => _updateConversion(),
                                decoration: const InputDecoration(hintText: '24'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('الوحدة الصغرى', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _baseUnitController,
                                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12, fontWeight: FontWeight.bold),
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(hintText: 'حبة/متر'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Live Conversion Calculator Inputs
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('العدد بالوحدة الكبرى', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _largeQtyController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 16),
                          onChanged: (_) => _updateConversion(),
                          decoration: InputDecoration(
                            hintText: 'العدد',
                            suffixText: _packagingUnitController.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.compare_arrows, color: AppColors.warning, size: 24),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('الناتج الفعلي', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.getBg(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.getBorder(context)),
                          ),
                          child: Text(
                            '${_calculatedBaseQty.toInt()} ${_baseUnitController.text}',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 15),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (_selectedItem != null)
                // Stock Equivalency Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getBorder(context)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'مُكافئ: ${(currentFactor > 0 ? _selectedItem!.currentStock / currentFactor : 0).toStringAsFixed(1)} ${_packagingUnitController.text}',
                        style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'المتاح: ${_selectedItem!.currentStock.toInt()} ${_baseUnitController.text}',
                        style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
