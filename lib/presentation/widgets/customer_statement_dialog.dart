import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/database/db_helper.dart';
import '../../data/models/customer_model.dart';
import 'customer_payment_dialog.dart';
import 'customer_autocomplete_field.dart';

class CustomerStatementDialog extends StatefulWidget {
  const CustomerStatementDialog({Key? key}) : super(key: key);

  @override
  State<CustomerStatementDialog> createState() => _CustomerStatementDialogState();
}

class _CustomerStatementDialogState extends State<CustomerStatementDialog> {
  late TextEditingController _customerNameController;
  late TextEditingController _customerCodeController;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  late CustomerModel _selectedCustomer;
  List<Map<String, dynamic>> _activeTransactions = [];
  double _totalDebit = 0.0;
  double _totalCredit = 0.0;
  double _finalBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = CustomerModel.sampleCustomers.firstWhere(
      (c) => c.code == '512',
      orElse: () => CustomerModel.sampleCustomers.isNotEmpty
          ? CustomerModel.sampleCustomers.first
          : CustomerModel(
              id: 'general',
              code: '000',
              name: 'عميل عام / جديد',
              phone: '-',
            ),
    );

    _customerNameController = TextEditingController(text: _selectedCustomer.name);
    _customerCodeController = TextEditingController(text: _selectedCustomer.code);

    _loadCustomerStatementData(_selectedCustomer);
  }

  void _loadCustomerStatementData(CustomerModel customer) async {
    _selectedCustomer = customer;
    _customerCodeController.text = customer.code;

    List<Map<String, dynamic>> baseTxs = [
      {'description': 'رصيد أول المدة', 'date': '01/01/2026', 'ref': '101', 'qty': 0.0, 'price': 0.0, 'amount': 0.0, 'balance': 0.0},
    ];

    // Load real dynamic sales orders created for this customer
    final dbHelper = DBHelper();
    final realSales = await dbHelper.getSalesForCustomer(customer.name);

    double currentRunningBalance = baseTxs.isNotEmpty ? (baseTxs.last['balance'] as num).toDouble() : 0.0;
    double calcDebit = baseTxs.where((t) => (t['amount'] as num) > 0).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
    double calcCredit = baseTxs.where((t) => (t['amount'] as num) < 0).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble().abs());

    for (var sale in realSales) {
      final total = (sale['total_amount'] as num).toDouble();
      currentRunningBalance += total;
      calcDebit += total;

      final items = sale['items'] as List<Map<String, dynamic>>? ?? [];
      String desc = 'فاتورة بيع صادر (رقم: ${sale['invoice_number']})';
      if (items.isNotEmpty) {
        desc = '${items.first['item_name']} (${items.length} أصناف)';
      }

      baseTxs.add({
        'description': desc,
        'date': sale['date'] ?? DateTime.now().toString().substring(0, 10),
        'ref': sale['invoice_number'] ?? sale['id'],
        'qty': items.isNotEmpty ? (items.first['qty'] as num).toDouble() : 1.0,
        'price': items.isNotEmpty ? (items.first['unit_price'] as num).toDouble() : total,
        'amount': total,
        'balance': currentRunningBalance,
      });
    }

    setState(() {
      _activeTransactions = baseTxs;
      _totalDebit = calcDebit;
      _totalCredit = calcCredit;
      _finalBalance = currentRunningBalance;
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerCodeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.getCardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.receipt_long_outlined, color: AppColors.primaryAccent, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📜 كشف حساب العميل والديون',
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

              // Customer Selector & Code with Instant Autocomplete Search
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _customerCodeController,
                      readOnly: true,
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 12),
                      decoration: const InputDecoration(labelText: 'كود العميل'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomerAutocompleteField(
                      controller: _customerNameController,
                      labelText: 'اسم العميل / المؤسسة (اكتب أول حروف لإظهار حسابه تلقائياً)',
                      onCustomerSelected: (customer) {
                        setState(() {
                          _loadCustomerStatementData(customer);
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Date Range Inputs
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startDateController,
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12),
                      decoration: const InputDecoration(labelText: 'الفترة من'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _endDateController,
                      style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 12),
                      decoration: const InputDecoration(labelText: 'إلى تاريخ'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.getBg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.getBorder(context)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_card, size: 16, color: Colors.white),
                      label: const Text('💵 تسجيل سند قبض', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => CustomerPaymentDialog(
                            initialCustomerName: _customerNameController.text.trim(),
                            currentBalance: _finalBalance,
                            onPaymentSaved: (newTx) {
                              setState(() {
                                _activeTransactions.add(newTx);
                                _finalBalance = (newTx['balance'] as num).toDouble();
                                _totalCredit += (newTx['amount'] as num).toDouble().abs();
                              });
                            },
                          ),
                        );
                      },
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'الرصيد المستحق: ${_finalBalance.toStringAsFixed(2)} ر.س',
                          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'مدين: ${_totalDebit.toStringAsFixed(0)} | دائن: ${_totalCredit.toStringAsFixed(0)}',
                          style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'سجل الفواتير والحركات والمدفوعات (${_activeTransactions.length} حركة):',
                style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activeTransactions.length,
                itemBuilder: (ctx, idx) {
                  final tx = _activeTransactions[idx];
                  final isPayment = (tx['amount'] as num).toDouble() < 0;
                  final amount = (tx['amount'] as num).toDouble().abs();
                  final qty = (tx['qty'] as num?)?.toDouble() ?? 0.0;
                  final price = (tx['price'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.getBg(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPayment ? AppColors.success : AppColors.getBorder(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${(tx['balance'] as double).toStringAsFixed(2)} ر.س',
                          style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isPayment)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(Icons.check_circle, color: AppColors.success, size: 14),
                                    ),
                                  Flexible(
                                    child: Text(
                                      tx['description'],
                                      style: TextStyle(
                                        color: isPayment ? AppColors.success : AppColors.getTextPrimary(context),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                qty > 0
                                    ? 'كمية: ${qty.toInt()} | سعر: ${price.toStringAsFixed(2)} | مبلغ: ${amount.toStringAsFixed(2)} ر.س'
                                    : 'تاريخ: ${tx['date']} | مرجع: ${tx['ref']} | مبلغ: ${amount.toStringAsFixed(2)} ر.س',
                                style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, color: Colors.white, size: 18),
                    label: const Text('📲 إرسال كشف الحساب عبر الواتساب', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      final pdfBytes = await PdfReportService.generateDetailedCustomerStatementPdf(
                        companyName: 'Benaa Co.',
                        vatNumber: '31057282200003',
                        crNumber: '7000418972',
                        customerName: _customerNameController.text.trim(),
                        customerCode: _customerCodeController.text.trim(),
                        startDate: _startDateController.text.trim(),
                        endDate: _endDateController.text.trim(),
                        previousBalance: 0.0,
                        totalDebit: _totalDebit,
                        totalCredit: _totalCredit,
                        finalBalance: _finalBalance,
                        transactions: _activeTransactions,
                      );
                      await Printing.sharePdf(
                        bytes: pdfBytes,
                        filename: 'كشف_حساب_${_customerNameController.text.trim()}.pdf',
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, color: AppColors.primaryAccent, size: 18),
                    label: const Text('📄 معاينة وطباعة PDF كشف الحساب', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryAccent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      final pdfBytes = await PdfReportService.generateDetailedCustomerStatementPdf(
                        companyName: 'Benaa Co.',
                        vatNumber: '31057282200003',
                        crNumber: '7000418972',
                        customerName: _customerNameController.text.trim(),
                        customerCode: _customerCodeController.text.trim(),
                        startDate: _startDateController.text.trim(),
                        endDate: _endDateController.text.trim(),
                        previousBalance: 0.0,
                        totalDebit: _totalDebit,
                        totalCredit: _totalCredit,
                        finalBalance: _finalBalance,
                        transactions: _activeTransactions,
                      );
                      await Printing.layoutPdf(
                        onLayout: (format) async => pdfBytes,
                        name: 'كشف_حساب_${_customerNameController.text.trim()}.pdf',
                      );
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
