import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/ocr_scanned_invoice_model.dart';
import '../../data/models/item_model.dart';
import '../providers/inventory_provider.dart';

class OcrInvoiceReviewSheet extends StatefulWidget {
  final OcrScannedInvoiceModel invoice;

  const OcrInvoiceReviewSheet({
    Key? key,
    required this.invoice,
  }) : super(key: key);

  @override
  State<OcrInvoiceReviewSheet> createState() => _OcrInvoiceReviewSheetState();
}

class _OcrInvoiceReviewSheetState extends State<OcrInvoiceReviewSheet> {
  late OcrScannedInvoiceModel _invoice;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  void _editItem(int index) {
    final item = _invoice.items[index];
    final nameCtrl = TextEditingController(text: item.itemName);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final priceCtrl = TextEditingController(text: item.unitPrice.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل بند الفاتورة', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم الصنف', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'سعر الوحدة', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent),
            onPressed: () {
              setState(() {
                item.itemName = nameCtrl.text.trim();
                item.quantity = double.tryParse(qtyCtrl.text) ?? item.quantity;
                item.unitPrice = double.tryParse(priceCtrl.text) ?? item.unitPrice;
                _invoice.recalculateTotals();
              });
              Navigator.pop(ctx);
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
  }

  Future<void> _commitToInventory() async {
    setState(() => _isSaving = true);
    await HapticsService.actionSuccess();

    final provider = Provider.of<InventoryProvider>(context, listen: false);

    // Add / Update items in local stock
    for (var scanned in _invoice.items) {
      final existingIndex = provider.localItems.indexWhere((i) => i.code == scanned.itemCode || i.name == scanned.itemName);
      if (existingIndex != -1) {
        final current = provider.localItems[existingIndex];
        await provider.updateItemStock(current.code, current.currentStock + scanned.quantity);
      } else {
        final newItem = ItemModel(
          code: scanned.itemCode,
          name: scanned.itemName,
          category: 'توريدات ذكية (OCR)',
          legacyUnit: scanned.unit,
          currentStock: scanned.quantity,
          unitPrice: scanned.unitPrice,
        );
        await provider.addItem(newItem);
      }
    }

    await NotificationService.showScanNotification(
      barcode: _invoice.invoiceNumber,
      itemName: 'ترحيل فاتورة: ${_invoice.partyName}',
      statusText: 'تمت إضافة ${_invoice.items.length} أصناف للمخزون بنجاح 📦',
    );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('تم ترحيل الفاتورة (${_invoice.invoiceNumber}) وإضافة الأصناف للمستودع بنجاح! 🚀'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getBorder(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.document_scanner, color: AppColors.primaryAccent, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'مراجعة وتأكيد الفاتورة الممسوحة',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_invoice.confidenceScore * 100).toInt()}% دقة التعرف 🎯',
                  style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Metadata Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getBg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorder(context)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('رقم الفاتورة: ${_invoice.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('التاريخ: ${_invoice.date.toIso8601String().split('T').first}', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الجهة: ${_invoice.partyName}', style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('النوع: ${_invoice.partyType}', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Items title
          Text(
            'الأصناف المستخرجة (${_invoice.items.length} صنف):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),

          const SizedBox(height: 8),

          // Items list
          Expanded(
            child: ListView.builder(
              itemCount: _invoice.items.length,
              itemBuilder: (ctx, index) {
                final it = _invoice.items[index];
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: AppColors.getCardBg(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.getBorder(context)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    title: Text(
                      it.itemName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    subtitle: Text(
                      'الكمية: ${it.quantity} ${it.unit}  ×  ${it.unitPrice} ريال',
                      style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${it.totalPrice.toStringAsFixed(2)} ر.س',
                          style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                          onPressed: () => _editItem(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Totals summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryAccent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المجموع: ${_invoice.subtotal.toStringAsFixed(2)} ر.س', style: const TextStyle(fontSize: 11)),
                    Text('الضريبة (15%): ${_invoice.taxAmount.toStringAsFixed(2)} ر.س', style: const TextStyle(fontSize: 11)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('الإجمالي شامل الضريبة:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(
                      '${_invoice.totalAmount.toStringAsFixed(2)} ر.س',
                      style: const TextStyle(color: AppColors.primaryAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('إلغاء'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.inventory_2_outlined, color: Colors.white),
                  label: Text(_isSaving ? 'جاري الترحيل...' : 'ترحيل للمستودع فوراً 🚀', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _isSaving ? null : _commitToInventory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
