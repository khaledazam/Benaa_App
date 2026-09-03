import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/notification_service.dart';
import '../providers/inventory_provider.dart';
import '../../data/models/item_model.dart';
import '../../core/services/ceiling_estimation_engine.dart';
import '../../core/services/decoration_estimation_engine.dart';
import 'decoration_estimator_dialog.dart';
import 'camera_scanner_dialog.dart';
import 'nfc_scanner_dialog.dart';

class CreateTransferDialog extends StatefulWidget {
  const CreateTransferDialog({Key? key}) : super(key: key);

  @override
  State<CreateTransferDialog> createState() => _CreateTransferDialogState();
}

class _CreateTransferDialogState extends State<CreateTransferDialog> {
  final TextEditingController _transferNumController = TextEditingController(
    text: '${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
  );
  final TextEditingController _fromWhController = TextEditingController();
  final TextEditingController _toWhController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final TextEditingController _itemCodeController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemQtyController = TextEditingController();
  final TextEditingController _cartonQtyController = TextEditingController();
  final TextEditingController _looseQtyController = TextEditingController();
  final TextEditingController _conversionFactorController = TextEditingController();

  final List<Map<String, dynamic>> _invoiceItems = [];

  @override
  void dispose() {
    _transferNumController.dispose();
    _fromWhController.dispose();
    _toWhController.dispose();
    _authorController.dispose();
    _notesController.dispose();
    _itemCodeController.dispose();
    _itemNameController.dispose();
    _itemQtyController.dispose();
    _cartonQtyController.dispose();
    _looseQtyController.dispose();
    _conversionFactorController.dispose();
    super.dispose();
  }

  String _selectedUnit = 'حبة';

  void _addItemToInvoice() {
    String code = _itemCodeController.text.trim();
    final name = _itemNameController.text.trim();

    // Auto-generate code if left empty (optional barcode field)
    if (code.isEmpty) {
      code = 'ITEM-${(DateTime.now().millisecondsSinceEpoch % 100000).toString()}';
    }

    final qty = double.tryParse(_itemQtyController.text) ?? 1.0;

    if (name.isEmpty || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم الصنف والكمية بشكل صحيح')),
      );
      return;
    }

    HapticsService.scanSuccess();

    String unitNote = _selectedUnit != 'حبة' ? 'الوحدة: $_selectedUnit' : 'حبة فردية';
    double actualPieces = qty;

    if (_selectedUnit.contains('متر مربع') || _selectedUnit.contains('م²')) {
      final mockItem = ItemModel(
        code: code,
        name: name,
        category: 'أسقف وديكور',
        legacyUnit: 'حبة',
        currentStock: 0,
        unitPrice: 0,
      );
      final res = CeilingEstimationEngine.calculateItemBreakdown(item: mockItem, areaM2: qty);
      actualPieces = res.totalPieces;
      unitNote = 'المساحة: $qty م² (${res.shortSummary})';
    }

    setState(() {
      _invoiceItems.add({
        'item_code': code,
        'item_name': name,
        'qty': actualPieces,
        'unit': _selectedUnit,
        'notes': unitNote,
      });
      _itemCodeController.clear();
      _itemNameController.clear();
      _itemQtyController.text = '1.0';
    });
  }

  void _saveNewInvoice() async {
    if (_transferNumController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة رقم الفاتورة / التحويل')),
      );
      return;
    }

    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إضافة صنف واحد على الأقل داخل الفاتورة')),
      );
      return;
    }

    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final transferId = await provider.createTransferInvoice(
      transferNumber: _transferNumController.text.trim(),
      fromWarehouse: _fromWhController.text.trim(),
      toWarehouse: _toWhController.text.trim(),
      author: _authorController.text.trim(),
      notes: _notesController.text.trim(),
      items: _invoiceItems,
    );

    await HapticsService.actionSuccess();
    await NotificationService.showSyncNotification(
      title: '📄 تم إنشاء فاتورة جديدة بنجاح',
      body: 'تم تسجيل فاتورة رقم #${_transferNumController.text} وإتاحتها للجرد فورياً.',
    );

    if (mounted) {
      Navigator.pop(context, transferId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.getCardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
      ),
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        height: 620,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.note_add, color: AppColors.primaryAccent, size: 28),
                Text(
                  'إنشاء فاتورة / شحنة واردة جديدة',
                  style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.getTextSecondary(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const Divider(color: AppColors.borderDark, height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Invoice details fields
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fromWhController,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'المصدر (المورد / المستودع)',
                              labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _transferNumController,
                            style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'رقم الفاتورة / الشحنة',
                              labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'إضافة منتجات للفاتورة:',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),

                    // Product Add inputs with Camera / NFC scanner buttons & Decoration Estimator
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.architecture, color: AppColors.success),
                          tooltip: '📐 مقايسة ديكور شاملة (أسقف، خشب، رخام، فوم)',
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (c) => DecorationEstimatorDialog(
                                onAddItemsToCart: (items) {
                                  setState(() {
                                    for (var item in items) {
                                      _invoiceItems.add({
                                        'item_code': item['item_code'],
                                        'item_name': item['item_name'],
                                        'expected_qty': item['qty'],
                                        'unit': item['unit'],
                                        'conversion_factor': 1.0,
                                        'unit_price': item['unit_price'] ?? 25.0,
                                        'notes': item['breakdown_notes'] ?? 'مقايسة ديكور آلية',
                                      });
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.success,
                                      content: Text('تمت إضافة ${items.length} بنود من المقايسة للشحنة بنجاح! 📐📦'),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryAccent),
                          tooltip: 'مسح الكاميرا',
                          onPressed: () async {
                            final code = await showDialog<String>(
                              context: context,
                              builder: (c) => const CameraScannerDialog(title: 'مسح باركود المنتج للفاتورة'),
                            );
                            if (code != null && code.isNotEmpty) {
                              _itemCodeController.text = code;
                              _itemNameController.text = 'منتج جديد ($code)';
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.nfc, color: AppColors.warning),
                          tooltip: 'مسح NFC',
                          onPressed: () async {
                            final code = await showDialog<String>(
                              context: context,
                              builder: (c) => const NfcScannerDialog(),
                            );
                            if (code != null && code.isNotEmpty) {
                              _itemCodeController.text = code;
                              _itemNameController.text = 'باليت NFC ($code)';
                            }
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _itemCodeController,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'الكود / الباركود (اختياري)',
                              hintText: 'يُولد تلقائياً إن تُرك فارغاً',
                              labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    const SizedBox(height: 8),

                    // Product Name Input with Live Autocomplete Suggestions
                    Consumer<InventoryProvider>(
                      builder: (context, provider, _) {
                        final allItems = provider.localItems;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            RawAutocomplete<ItemModel>(
                              textEditingController: _itemNameController,
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
                                _itemNameController.text = selection.name;
                                _itemCodeController.text = selection.code;
                                setState(() {
                                  _selectedUnit = selection.unit;
                                });
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13, fontWeight: FontWeight.bold),
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'اسم المنتج / الصنف (اكتب أول حروف للاقتراح والتجميع)',
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
                                              'كود: ${option.code} | الرصيد المتاح بالمستودع: ${option.currentStock.toInt()} ${option.unit}',
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
                            if (_itemNameController.text.trim().isNotEmpty) ...[
                              Builder(builder: (_) {
                                final matched = allItems.firstWhere(
                                  (i) => i.name.trim().toLowerCase() == _itemNameController.text.trim().toLowerCase(),
                                  orElse: () => ItemModel(code: '', name: '', category: '', legacyUnit: 'حبة', currentStock: -1),
                                );
                                if (matched.currentStock >= 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '📦 صنف موجود بالمستودع (الرصيد القائم: ${matched.currentStock.toInt()} ${matched.unit}) - سيتم تجميع وتزويد التوريد الجديد عليه تلقائياً',
                                      style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.right,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Multi-Unit Selector (وحدة القياس والتعبئة) + Quantity Input
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Builder(
                            builder: (context) {
                              final standardUnits = ['حبة', 'لوح', 'متر', 'متر مربع', 'كرتونة', 'طبلية', 'كيس', 'طن', 'كجم', 'ربطة', 'حزمة', 'علبة', 'طرد', 'جالون', 'لتر'];
                              final currentVal = _selectedUnit.trim().isNotEmpty ? _selectedUnit.trim() : 'حبة';
                              final itemsList = standardUnits.contains(currentVal) ? standardUnits : [...standardUnits, currentVal];

                              return DropdownButtonFormField<String>(
                                value: currentVal,
                                dropdownColor: AppColors.getCardBg(context),
                                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'وحدة القياس / التعبئة',
                                  labelStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10),
                                ),
                                items: itemsList.map((u) {
                                  return DropdownMenuItem<String>(
                                    value: u,
                                    child: Text(u == 'حبة' ? 'حبة / قطعة' : u == 'متر مربع' ? 'متر مربع (m²)' : u == 'طبلية' ? 'طبلية / لوح' : u),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedUnit = val);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _itemQtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'الكمية المستلمة',
                              labelStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10),
                              hintText: '10.0',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onPressed: _addItemToInvoice,
                          child: const Text('إضافة للصنف'),
                        ),
                      ],
                    ),

                    if (_selectedUnit.contains('متر مربع') || _selectedUnit.contains('م²')) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final areaVal = double.tryParse(_itemQtyController.text) ?? 0.0;
                          final nameVal = _itemNameController.text.trim();
                          final mockItem = ItemModel(
                            code: _itemCodeController.text.trim(),
                            name: nameVal.isNotEmpty ? nameVal : 'صنف ديكور',
                            category: 'أسقف وديكور',
                            legacyUnit: 'حبة',
                            currentStock: 0,
                            unitPrice: 0,
                          );
                          final res = CeilingEstimationEngine.calculateItemBreakdown(item: mockItem, areaM2: areaVal > 0 ? areaVal : 100.0);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.success.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: AppColors.success, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '📐 التفكيك الهندسي التلقائي: ${res.formattedBreakdown}',
                                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 16),

                    const Text(
                      'المنتجات المضافة في الفاتورة:',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),

                    if (_invoiceItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Text(
                          'لم يتم إضافة منتجات للفاتورة بعد.\nاكتب الكود والاسم واضغط إضافة أو امسح الباركود بالكاميرا.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _invoiceItems.length,
                        itemBuilder: (ctx, idx) {
                          final item = _invoiceItems[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            color: AppColors.bgDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.borderDark),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(item['item_name'], style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                              subtitle: Text('الكود: ${item['item_code']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.right),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${item['qty'].toInt()} حبة', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _invoiceItems.removeAt(idx);
                                      });
                                    },
                                  ),
                                ],
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: Text('حفظ الفاتورة (${_invoiceItems.length} صنف)'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: _saveNewInvoice,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
