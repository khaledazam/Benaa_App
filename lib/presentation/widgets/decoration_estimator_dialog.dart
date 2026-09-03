import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/decoration_estimation_engine.dart';
import '../../core/services/haptics_service.dart';
import '../providers/inventory_provider.dart';

class DecorationEstimatorDialog extends StatefulWidget {
  final Function(List<Map<String, dynamic>> cartItems) onAddItemsToCart;

  const DecorationEstimatorDialog({
    Key? key,
    required this.onAddItemsToCart,
  }) : super(key: key);

  @override
  State<DecorationEstimatorDialog> createState() => _DecorationEstimatorDialogState();
}

class _DecorationEstimatorDialogState extends State<DecorationEstimatorDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1. Ceiling Inputs
  final TextEditingController _ceilingAreaController = TextEditingController(text: '50');

  // 2. WPC Wood Inputs
  final TextEditingController _wpcWidthController = TextEditingController(text: '4.0');
  final TextEditingController _wpcHeightController = TextEditingController(text: '2.8');
  double _wpcPanelWidthCm = 16.0;

  // 3. PVC Marble Inputs
  final TextEditingController _pvcWidthController = TextEditingController(text: '3.66');
  final TextEditingController _pvcHeightController = TextEditingController(text: '2.8');

  // 4. Foam Frames Inputs
  final TextEditingController _frameCountController = TextEditingController(text: '6');
  final TextEditingController _frameWidthController = TextEditingController(text: '1.2');
  final TextEditingController _frameHeightController = TextEditingController(text: '0.8');

  // Selected items inside current estimate for batch addition
  final Set<String> _selectedItemKeys = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedItemKeys.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ceilingAreaController.dispose();
    _wpcWidthController.dispose();
    _wpcHeightController.dispose();
    _pvcWidthController.dispose();
    _pvcHeightController.dispose();
    _frameCountController.dispose();
    _frameWidthController.dispose();
    _frameHeightController.dispose();
    super.dispose();
  }

  DecorationProjectEstimate _getCurrentEstimate() {
    switch (_tabController.index) {
      case 0: // Ceiling
        final area = double.tryParse(_ceilingAreaController.text) ?? 0.0;
        return DecorationEstimationEngine.estimateCeilingProject(area);

      case 1: // WPC Wood
        final width = double.tryParse(_wpcWidthController.text) ?? 0.0;
        final height = double.tryParse(_wpcHeightController.text) ?? 0.0;
        return DecorationEstimationEngine.estimateWpcWoodProject(
          wallWidthM: width,
          wallHeightM: height,
          panelWidthCm: _wpcPanelWidthCm,
        );

      case 2: // PVC Marble
        final width = double.tryParse(_pvcWidthController.text) ?? 0.0;
        final height = double.tryParse(_pvcHeightController.text) ?? 0.0;
        return DecorationEstimationEngine.estimatePvcMarbleProject(
          wallWidthM: width,
          wallHeightM: height,
        );

      case 3: // Foam Frames
        final count = int.tryParse(_frameCountController.text) ?? 1;
        final width = double.tryParse(_frameWidthController.text) ?? 1.0;
        final height = double.tryParse(_frameHeightController.text) ?? 1.0;
        return DecorationEstimationEngine.estimateFoamFramesProject(
          frameCount: count,
          frameWidthM: width,
          frameHeightM: height,
        );

      default:
        return DecorationEstimationEngine.estimateCeilingProject(50);
    }
  }

  void _addItems(List<DecorationItemEstimate> itemsToAdd, InventoryProvider provider) {
    if (itemsToAdd.isEmpty) return;

    final warehouseItems = provider.localItems;
    final List<Map<String, dynamic>> cartItems = [];

    for (var estimateItem in itemsToAdd) {
      final matched = DecorationEstimationEngine.findMatchingWarehouseItem(estimateItem, warehouseItems);

      final itemCode = matched != null ? matched.code : 'DEC-${estimateItem.role.name}-${DateTime.now().millisecondsSinceEpoch % 10000}';
      final itemName = matched != null ? matched.name : estimateItem.itemName;
      final unitPrice = matched != null ? matched.unitPrice : estimateItem.estimatedUnitPrice;

      cartItems.add({
        'item_code': itemCode,
        'item_name': itemName,
        'qty': estimateItem.quantity,
        'unit': estimateItem.unit,
        'base_qty': estimateItem.quantity,
        'unit_price': unitPrice,
        'total': estimateItem.quantity * unitPrice,
        'breakdown_notes': '${estimateItem.breakdownSummary} (${estimateItem.calculationFormulaNote})',
      });
    }

    widget.onAddItemsToCart(cartItems);
    HapticsService.actionSuccess();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final estimate = _getCurrentEstimate();

    return Dialog(
      backgroundColor: AppColors.getCardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryAccent.withOpacity(0.4)),
                  ),
                  child: const Text(
                    '📐 محرك المقايسات الشامل',
                    style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    'مقايسات الديكور والتشطيبات',
                    style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.getTextSecondary(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.getBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primaryAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.getTextSecondary(context),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                isScrollable: true,
                tabs: const [
                  Tab(text: '🏗️ أسقف وجبس'),
                  Tab(text: '🪵 بديل خشب WPC'),
                  Tab(text: '🏛️ بديل رخام PVC'),
                  Tab(text: '🖼️ بانوهات فوم'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Dimension Inputs Section
            _buildDimensionInputSection(),

            const SizedBox(height: 12),

            // Project Summary Bar & Select All Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        _selectedItemKeys.length == estimate.items.length ? Icons.check_box : Icons.check_box_outline_blank,
                        color: AppColors.primaryAccent,
                        size: 18,
                      ),
                      label: Text(
                        _selectedItemKeys.length == estimate.items.length ? 'إلغاء تحديد الكل' : 'تحديد الكل (${estimate.items.length})',
                        style: const TextStyle(color: AppColors.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          if (_selectedItemKeys.length == estimate.items.length) {
                            _selectedItemKeys.clear();
                          } else {
                            _selectedItemKeys.addAll(estimate.items.map((i) => i.itemName));
                          }
                        });
                      },
                    ),
                  ],
                ),
                Text(
                  'التفكيك وتقدير الاحتياج الفعلي:',
                  style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Results List
            Expanded(
              child: ListView.builder(
                itemCount: estimate.items.length,
                itemBuilder: (ctx, idx) {
                  final item = estimate.items[idx];
                  final isSelected = _selectedItemKeys.contains(item.itemName);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryAccent.withOpacity(0.08) : AppColors.getBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryAccent.withOpacity(0.5) : AppColors.getBorder(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Quick Add Single Item
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart, color: AppColors.success, size: 22),
                          tooltip: 'إضافة هذا البند فقط للسلة',
                          onPressed: () => _addItems([item], provider),
                        ),

                        // Unit Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.quantity.toInt()} ${item.unit}',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item.itemName,
                                style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.breakdownSummary,
                                style: const TextStyle(color: AppColors.primaryAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.right,
                              ),
                              Text(
                                item.calculationFormulaNote,
                                style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),

                        // Checkbox
                        Checkbox(
                          value: isSelected,
                          activeColor: AppColors.primaryAccent,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedItemKeys.add(item.itemName);
                              } else {
                                _selectedItemKeys.remove(item.itemName);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(color: AppColors.borderDark, height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.done_all),
                  label: Text(
                    _selectedItemKeys.isEmpty || _selectedItemKeys.length == estimate.items.length
                        ? '📥 إضافة كافة بنود المقايسة (${estimate.items.length})'
                        : '📥 إضافة البنود المحددة (${_selectedItemKeys.length}) للسلة',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    final itemsToAdd = _selectedItemKeys.isEmpty
                        ? estimate.items
                        : estimate.items.where((i) => _selectedItemKeys.contains(i.itemName)).toList();
                    _addItems(itemsToAdd, provider);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionInputSection() {
    switch (_tabController.index) {
      case 0: // Ceiling
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ceilingAreaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'المساحة الإجمالية للسقف (م²)',
                  prefixIcon: Icon(Icons.square_foot, color: AppColors.primaryAccent),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        );

      case 1: // WPC Wood
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wpcHeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'ارتفاع الجدار (متر)',
                      prefixIcon: Icon(Icons.height, color: AppColors.primaryAccent),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _wpcWidthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'عرض الجدار (متر)',
                      prefixIcon: Icon(Icons.straighten, color: AppColors.primaryAccent),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ChoiceChip(
                  label: const Text('شريحة 16 سم'),
                  selected: _wpcPanelWidthCm == 16.0,
                  onSelected: (val) {
                    if (val) setState(() => _wpcPanelWidthCm = 16.0);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('شريحة 20 سم'),
                  selected: _wpcPanelWidthCm == 20.0,
                  onSelected: (val) {
                    if (val) setState(() => _wpcPanelWidthCm = 20.0);
                  },
                ),
                const SizedBox(width: 10),
                Text('عرض الشريحة:', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12)),
              ],
            ),
          ],
        );

      case 2: // PVC Marble
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pvcHeightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'ارتفاع الجدار (متر)',
                  prefixIcon: Icon(Icons.height, color: AppColors.primaryAccent),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _pvcWidthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'عرض الجدار (متر)',
                  prefixIcon: Icon(Icons.straighten, color: AppColors.primaryAccent),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        );

      case 3: // Foam Frames
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _frameCountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'عدد الإطارات (البانوهات)',
                      prefixIcon: Icon(Icons.grid_view, color: AppColors.primaryAccent),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _frameWidthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'عرض الإطار (م)',
                      prefixIcon: Icon(Icons.straighten, color: AppColors.primaryAccent),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _frameHeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'ارتفاع الإطار (م)',
                      prefixIcon: Icon(Icons.height, color: AppColors.primaryAccent),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
