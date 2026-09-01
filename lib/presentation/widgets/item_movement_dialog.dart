import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../data/models/item_model.dart';
import '../../core/services/unit_conversion_engine.dart';

class ItemMovementDialog extends StatefulWidget {
  final ItemModel item;

  const ItemMovementDialog({Key? key, required this.item}) : super(key: key);

  @override
  State<ItemMovementDialog> createState() => _ItemMovementDialogState();
}

class _ItemMovementDialogState extends State<ItemMovementDialog> {
  final DBHelper _dbHelper = DBHelper();

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Dialog(
      backgroundColor: AppColors.getCardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.primaryAccent, width: 1),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 550,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.history_outlined, color: AppColors.primaryAccent, size: 28),
                Expanded(
                  child: Text(
                    'سجل حركة الصنف: ${item.name}',
                    style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 15, fontWeight: FontWeight.bold),
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

            const Divider(color: AppColors.borderDark, height: 16),

            // Item Quick Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('كود الصنف', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                      Text(item.code, style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('الوحدة المسجلة', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryAccent.withOpacity(0.4)),
                        ),
                        child: Text(
                          item.unit,
                          style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('التصنيف', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                      Text(item.category, style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('الرصيد الحالي', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
                      Text('${item.currentStock.toInt()} ${item.unit}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: FutureBuilder<List<StockMovementSnapshot>>(
                future: _dbHelper.getStockMovements(item.code),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final logs = snapshot.data ?? [];

                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 48, color: AppColors.getTextSecondary(context).withOpacity(0.5)),
                          const SizedBox(height: 10),
                          Text(
                            'لا توجد حركات مخزنية جديدة مسجلة على هذا الصنف حتى الآن',
                            style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الرصيد الافتتاحي القائم بالمستودع: ${item.currentStock.toInt()} ${item.unit}',
                            style: const TextStyle(color: AppColors.success, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (ctx, idx) {
                      final log = logs[idx];
                      final isAddition = log.transactionType.contains('ADD') || log.transactionType.contains('RETURN') || log.transactionType.contains('RECEIVE');
                      final color = isAddition ? AppColors.success : AppColors.danger;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.getBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.getBorder(context)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${isAddition ? "+" : "-"}${log.enteredQuantity} ${log.enteredUnit}',
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  'أساسي: ${log.baseQuantity} ${log.baseUnit}',
                                  style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      log.transactionType,
                                      style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(isAddition ? Icons.add_circle_outline : Icons.remove_circle_outline, color: color, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '📅 ${log.date} ${log.notes != null ? "| " + log.notes! : ""}',
                                  style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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
