class SaleOrderItemModel {
  final int? id;
  final String saleId;
  final String itemCode;
  final String itemName;
  final double qty;
  final double unitPrice;

  SaleOrderItemModel({
    this.id,
    required this.saleId,
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.unitPrice,
  });

  double get totalPrice => qty * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'item_code': itemCode,
      'item_name': itemName,
      'qty': qty,
      'unit_price': unitPrice,
    };
  }

  factory SaleOrderItemModel.fromMap(Map<String, dynamic> map) {
    return SaleOrderItemModel(
      id: map['id'],
      saleId: map['sale_id'] ?? '',
      itemCode: map['item_code']?.toString() ?? '',
      itemName: map['item_name'] ?? '',
      qty: (map['qty'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SaleOrderModel {
  final String id;
  final String invoiceNumber;
  final String shopName;
  final String date;
  final double totalAmount;
  final String status; // 'completed', 'pending_sync'
  final List<SaleOrderItemModel> items;

  SaleOrderModel({
    required this.id,
    required this.invoiceNumber,
    required this.shopName,
    required this.date,
    required this.totalAmount,
    required this.status,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'shop_name': shopName,
      'date': date,
      'total_amount': totalAmount,
      'status': status,
    };
  }

  factory SaleOrderModel.fromMap(Map<String, dynamic> map, {List<SaleOrderItemModel>? items}) {
    return SaleOrderModel(
      id: map['id'] ?? '',
      invoiceNumber: map['invoice_number'] ?? '',
      shopName: map['shop_name'] ?? '',
      date: map['date'] ?? '',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'completed',
      items: items ?? [],
    );
  }
}
