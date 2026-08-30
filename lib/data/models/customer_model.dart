class CustomerModel {
  final String id;
  final String code;
  final String name;
  final String phone;
  final String vatNumber;
  final String address;
  double currentBalance;

  CustomerModel({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    this.vatNumber = '',
    this.address = '',
    this.currentBalance = 0.0,
  });

  // Dynamic customer repository
  static final List<CustomerModel> _customers = [];

  static List<CustomerModel> get sampleCustomers => _customers;

  static void clearAllCustomers() {
    _customers.clear();
  }

  /// Register or update customer balance after a new sale order
  static void registerSaleForCustomer(String shopName, double totalAmount, {String phone = ''}) {
    final query = shopName.trim().toLowerCase();
    final index = _customers.indexWhere((c) =>
        c.name.toLowerCase().contains(query) ||
        query.contains(c.name.toLowerCase()) ||
        c.code == query);

    if (index != -1) {
      _customers[index].currentBalance += totalAmount;
    } else {
      final newCode = (500 + _customers.length + 1).toString();
      _customers.add(CustomerModel(
        id: 'cust-${DateTime.now().millisecondsSinceEpoch}',
        code: newCode,
        name: shopName.trim().isNotEmpty ? shopName.trim() : 'عميل جديد',
        phone: phone.isNotEmpty ? phone : '0500000000',
        currentBalance: totalAmount,
      ));
    }
  }

  /// Register customer payment reducing debt balance
  static void registerPaymentForCustomer(String shopName, double paymentAmount) {
    final query = shopName.trim().toLowerCase();
    final index = _customers.indexWhere((c) =>
        c.name.toLowerCase().contains(query) ||
        query.contains(c.name.toLowerCase()) ||
        c.code == query);

    if (index != -1) {
      _customers[index].currentBalance = (_customers[index].currentBalance - paymentAmount).clamp(0.0, double.infinity);
    }
  }

  /// Register customer return deducting from outstanding debt
  static void registerCustomerReturn(String shopName, double returnAmount) {
    final query = shopName.trim().toLowerCase();
    final index = _customers.indexWhere((c) =>
        c.name.toLowerCase().contains(query) ||
        query.contains(c.name.toLowerCase()) ||
        c.code == query);

    if (index != -1) {
      _customers[index].currentBalance = (_customers[index].currentBalance - returnAmount).clamp(0.0, double.infinity);
    }
  }
}
