import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/pdf_report_service.dart';
import '../../data/models/customer_model.dart';
import 'customer_autocomplete_field.dart';

class CustomerPaymentDialog extends StatefulWidget {
  final String initialCustomerName;
  final double currentBalance;
  final Function(Map<String, dynamic> newPaymentTransaction)? onPaymentSaved;

  const CustomerPaymentDialog({
    Key? key,
    this.initialCustomerName = 'مؤسسة صلاح سعد أحمد الحارثي',
    this.currentBalance = 33565.50,
    this.onPaymentSaved,
  }) : super(key: key);

  @override
  State<CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<CustomerPaymentDialog> {
  late TextEditingController _customerNameController;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _refNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _paymentMethod = 'تحويل بنكي';
  final List<String> _methods = ['نقداً', 'تحويل بنكي', 'شيك', 'مدى / بطاقة'];

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(text: widget.initialCustomerName);
    _refNumberController.text = 'TRF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _amountController.dispose();
    _refNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double amountPaid = double.tryParse(_amountController.text) ?? 0.0;
    final double remaining = (widget.currentBalance - amountPaid).clamp(0.0, double.infinity);

    return Dialog(
      backgroundColor: AppColors.getCardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.success, width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.payments_outlined, color: AppColors.success, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💵 تسجيل سند قبض / سداد عميل',
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

              const Divider(color: AppColors.borderDark),

              // Current Balance Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.getBg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.getBorder(context)),
                ),
                child: Column(
                  children: [
                    Text(
                      'الرصيد المستحق الحالي على العميل: ${widget.currentBalance.toStringAsFixed(2)} ر.س',
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    if (amountPaid > 0)
                      Text(
                        'الرصيد المتبقي بعد هذا السداد: ${remaining.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              CustomerAutocompleteField(
                controller: _customerNameController,
                labelText: 'اسم العميل المسدد (ابحث بأول الحروف أو الكود)',
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'المبلغ المدفوع / المقبوض (ر.س)',
                  hintText: 'مثال: 5000',
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.success),
                ),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _paymentMethod,
                isExpanded: true,
                dropdownColor: AppColors.getCardBg(context),
                style: TextStyle(color: AppColors.getTextPrimary(context)),
                decoration: const InputDecoration(
                  labelText: 'طريقة السداد',
                  prefixIcon: Icon(Icons.account_balance_wallet, color: AppColors.info),
                ),
                items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _refNumberController,
                style: TextStyle(color: AppColors.getTextPrimary(context)),
                decoration: const InputDecoration(
                  labelText: 'رقم المرجع / التحويل / الشيك',
                  prefixIcon: Icon(Icons.tag, color: AppColors.primaryAccent),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _notesController,
                style: TextStyle(color: AppColors.getTextPrimary(context)),
                decoration: const InputDecoration(
                  labelText: 'ملاحظات وتفاصيل السداد',
                  prefixIcon: Icon(Icons.note, color: AppColors.primaryAccent),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('✅ حفظ وتصدير سند القبض'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        if (amountPaid <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('⚠️ يرجى إدخال مبلغ سداد صحيح!')),
                          );
                          return;
                        }

                        final newTx = {
                          'description': 'سداد ($_paymentMethod)',
                          'date': DateTime.now().toString().substring(0, 10),
                          'ref': _refNumberController.text.trim(),
                          'qty': 0.0,
                          'price': 0.0,
                          'amount': -amountPaid,
                          'balance': remaining,
                        };

                        CustomerModel.registerPaymentForCustomer(
                          _customerNameController.text.trim(),
                          amountPaid,
                        );

                        if (widget.onPaymentSaved != null) {
                          widget.onPaymentSaved!(newTx);
                        }

                        try {
                          final pdfBytes = await PdfReportService.generatePaymentReceiptPdf(
                            receiptNumber: _refNumberController.text.trim(),
                            customerName: _customerNameController.text.trim(),
                            amountPaid: amountPaid,
                            paymentMethod: _paymentMethod,
                            date: DateTime.now().toString().substring(0, 10),
                            refNumber: _refNumberController.text.trim(),
                            notes: _notesController.text.trim(),
                            remainingBalance: remaining,
                          );

                          await Printing.layoutPdf(
                            onLayout: (format) async => pdfBytes,
                            name: 'سند_قبض_${_refNumberController.text.trim()}.pdf',
                          );
                        } catch (e) {
                          // Handle any browser pdf preview issues
                        }

                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
