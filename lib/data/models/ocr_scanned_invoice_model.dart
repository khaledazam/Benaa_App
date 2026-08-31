class ScannedInvoiceItem {
  String itemCode;
  String itemName;
  double quantity;
  String unit;
  double unitPrice;
  double totalPrice;

  ScannedInvoiceItem({
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    this.unit = 'حبة',
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  factory ScannedInvoiceItem.fromMap(Map<String, dynamic> map) {
    return ScannedInvoiceItem(
      itemCode: map['item_code'] ?? '',
      itemName: map['item_name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'حبة',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OcrScannedInvoiceModel {
  String invoiceNumber;
  String partyName; // Supplier or Customer
  String partyType; // 'مورد' (Supplier) or 'عميل' (Customer)
  DateTime date;
  double subtotal;
  double taxRate; // default 0.15 (15% VAT)
  double taxAmount;
  double totalAmount;
  double confidenceScore; // 0.0 to 1.0
  List<ScannedInvoiceItem> items;
  String rawText;

  OcrScannedInvoiceModel({
    required this.invoiceNumber,
    required this.partyName,
    this.partyType = 'مورد',
    required this.date,
    required this.subtotal,
    this.taxRate = 0.15,
    required this.taxAmount,
    required this.totalAmount,
    this.confidenceScore = 0.95,
    required this.items,
    this.rawText = '',
  });

  void recalculateTotals() {
    double sum = 0.0;
    for (var item in items) {
      item.totalPrice = item.quantity * item.unitPrice;
      sum += item.totalPrice;
    }
    subtotal = sum;
    taxAmount = subtotal * taxRate;
    totalAmount = subtotal + taxAmount;
  }
}
