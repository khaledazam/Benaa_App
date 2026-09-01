import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/item_model.dart';
import '../providers/inventory_provider.dart';
import '../../core/services/haptics_service.dart';
import '../widgets/camera_scanner_dialog.dart';

import '../../core/services/period_archive_filter_service.dart';
import '../widgets/archive_period_selector_bar.dart';

class StockAuditScreen extends StatefulWidget {
  const StockAuditScreen({Key? key}) : super(key: key);

  @override
  State<StockAuditScreen> createState() => _StockAuditScreenState();
}

class _StockAuditScreenState extends State<StockAuditScreen> {
  ItemModel? _selectedItem;
  final TextEditingController _countedQtyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _auditSearchController = TextEditingController();
  String _auditSearchQuery = '';
  ArchivePeriodType _archivePeriod = ArchivePeriodType.allTime;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadLocalItems();
    });
  }

  @override
  void dispose() {
    _countedQtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveAuditRecord(BuildContext context) async {
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الصنف أولاً')),
      );
      return;
    }

    final counted = double.tryParse(_countedQtyController.text);
    if (counted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال كمية مجرودة صحيحة')),
      );
      return;
    }

    final provider = Provider.of<InventoryProvider>(context, listen: false);
    await provider.recordPeriodicAudit(
      _selectedItem!.code,
      _selectedItem!.name,
      _selectedItem!.currentStock,
      counted,
      _notesController.text,
    );

    await HapticsService.actionSuccess();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('تم تسجيل عملية الجرد الدوري وتعديل رصيد الصنف محلياً بنجاح!'),
        ),
      );
      setState(() {
        _selectedItem = null;
        _countedQtyController.clear();
        _notesController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBg(context),
      appBar: AppBar(
        title: const Text('الجرد الدوري (عند الطلب)'),
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final items = provider.localItems;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ArchivePeriodSelectorBar(
                  currentPeriod: _archivePeriod,
                  customDateRange: _customDateRange,
                  totalCount: items.length,
                  totalAmount: items.fold(0.0, (sum, i) => sum + (i.currentStock * i.unitPrice)),
                  countLabel: 'أصناف المستودع',
                  amountLabel: 'تقييم المخزون المجرود',
                  onPeriodChanged: (selectedType, range) {
                    setState(() {
                      _archivePeriod = selectedType;
                      _customDateRange = range;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'يتم إجراء الجرد الدوري بطلب من المشرف أو الإدارة لمطابقة الرصيد الفعلي في مستودع بريدة مع الرصيد المسجل.',
                          style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryAccent),
                      tooltip: 'مسح باركود الصنف بالكاميرا الحية',
                      onPressed: () async {
                        final scannedCode = await showDialog<String>(
                          context: context,
                          builder: (ctx) => const CameraScannerDialog(
                            title: 'مسح باركود الصنف للجرد الدوري',
                          ),
                        );
                        if (scannedCode != null && scannedCode.isNotEmpty) {
                          final itemsList = provider.localItems;
                          final matched = itemsList.where((i) => i.code == scannedCode || i.code.contains(scannedCode));
                          if (matched.isNotEmpty) {
                            setState(() {
                              _selectedItem = matched.first;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'اختر الصنف المراد جرده:',
                        style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Live Search Bar by Name, Category, or Code
                TextField(
                  controller: _auditSearchController,
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                  onChanged: (val) => setState(() => _auditSearchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم الصنف، التصنيف، أو الكود...',
                    hintStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryAccent),
                    suffixIcon: _auditSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              _auditSearchController.clear();
                              setState(() => _auditSearchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 8),

                Builder(
                  builder: (ctx) {
                    final q = _auditSearchQuery.toLowerCase();
                    final filteredItems = _auditSearchQuery.isEmpty
                        ? items
                        : items.where((i) =>
                            i.name.toLowerCase().contains(q) ||
                            i.category.toLowerCase().contains(q) ||
                            i.code.toLowerCase().contains(q)).toList();

                    return DropdownButtonFormField<ItemModel>(
                      value: filteredItems.contains(_selectedItem) ? _selectedItem : null,
                      isExpanded: true,
                      dropdownColor: AppColors.bgCard,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: filteredItems.isEmpty
                            ? 'لا يوجد صنف يطابق البحث'
                            : '-- اختر صنف من مخزن بريدة (${filteredItems.length} صنف) --',
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      items: filteredItems.map((item) {
                        return DropdownMenuItem<ItemModel>(
                          value: item,
                          child: Text(
                            'كود [${item.code}] - ${item.name} | ${item.category}',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedItem = val;
                          if (val != null) {
                            _countedQtyController.text = val.currentStock.toInt().toString();
                          }
                        });
                      },
                    );
                  },
                ),

                if (_selectedItem != null) ...[
                  const SizedBox(height: 20),
                  Card(
                    color: AppColors.bgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.borderDark),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('كود الصنف: ${_selectedItem!.code}', style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('اسم الصنف: ${_selectedItem!.name}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                          const Divider(color: AppColors.borderDark, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primaryAccent.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      'الوحدة: ${_selectedItem!.unit}',
                                      style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${_selectedItem!.currentStock.toInt()} ${_selectedItem!.unit}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const Text('الرصيد والوحدة المسجلة بالسيستم:', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _countedQtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'الكمية الفعلية المجرودة بالمستودع (بالـ ${_selectedItem!.unit})',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.calculate_outlined, color: AppColors.primaryAccent),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _notesController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الجرد (سبب الفارق إن وجد)',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.note_alt_outlined, color: AppColors.textSecondary),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('اعتماد الجرد الدوري وتحديث الرصيد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                      ),
                      onPressed: () => _saveAuditRecord(context),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
