import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/customer_model.dart';

class CustomerAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final ValueChanged<CustomerModel>? onCustomerSelected;

  const CustomerAutocompleteField({
    Key? key,
    required this.controller,
    this.labelText = 'اسم المحل / العميل (ابحث بأول الحروف أو الكود)',
    this.onCustomerSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<CustomerModel>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return CustomerModel.sampleCustomers;
        }
        return CustomerModel.sampleCustomers.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.code.toLowerCase().contains(query) ||
              c.phone.contains(query);
        });
      },
      displayStringForOption: (CustomerModel option) => option.name,
      fieldViewBuilder: (context, fieldTextEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: fieldTextEditingController,
          focusNode: focusNode,
          style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: 'اكتب أول حروف من الاسم أو الكود...',
            labelStyle: TextStyle(color: AppColors.getTextSecondary(context)),
            prefixIcon: const Icon(Icons.search_outlined, color: AppColors.primaryAccent),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryAccent),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.getCardBg(context),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryAccent, width: 1),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: options.length,
                separatorBuilder: (_, __) => Divider(color: AppColors.getBorder(context), height: 1),
                itemBuilder: (context, index) {
                  final customer = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'رصيد: ${customer.currentBalance.toStringAsFixed(2)} ر.س',
                          style: TextStyle(
                            color: customer.currentBalance > 0 ? AppColors.danger : AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customer.name,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'كود: ${customer.code} | هاتف: ${customer.phone}',
                        style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 10),
                      ),
                    ),
                    onTap: () {
                      onSelected(customer);
                      if (onCustomerSelected != null) {
                        onCustomerSelected!(customer);
                      }
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
