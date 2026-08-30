enum ReturnType { salesReturn, purchaseReturn }

class ReturnItemModel {
  final String itemCode;
  final String itemName;
  final double returnedQty;
  final String unit;
  final double baseQty;
  final double unitPrice;
  final String reason;

  ReturnItemModel({
    required this.itemCode,
    required this.itemName,
    required this.returnedQty,
    required this.unit,
    required this.baseQty,
    required this.unitPrice,
    this.reason = 'مرتجع عام',
  });

  double get totalPrice => returnedQty * unitPrice;

  Map<String, dynamic> toMap(String returnId) {
    return {
      'return_id': returnId,
      'item_code': itemCode,
      'item_name': itemName,
      'returned_qty': returnedQty,
      'unit': unit,
      'base_qty': baseQty,
      'unit_price': unitPrice,
      'reason': reason,
    };
  }

  factory ReturnItemModel.fromMap(Map<String, dynamic> map) {
    return ReturnItemModel(
      itemCode: map['item_code'] ?? '',
      itemName: map['item_name'] ?? '',
      returnedQty: (map['returned_qty'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? 'حبة',
      baseQty: (map['base_qty'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] ?? 'مرتجع عام',
    );
  }
}

class ReturnInvoiceModel {
  final String id;
  final String returnNumber;
  final ReturnType returnType; // salesReturn or purchaseReturn
  final String partyName; // Customer Name or Supplier Name
  final String date;
  final String refundMethod; // cash, credit, bank
  final String notes;
  final List<ReturnItemModel> items;

  ReturnInvoiceModel({
    required this.id,
    required this.returnNumber,
    required this.returnType,
    required this.partyName,
    required this.date,
    required this.refundMethod,
    required this.notes,
    required this.items,
  });

  double get totalAmount => items.fold(0.0, (sum, i) => sum + i.totalPrice);

  String get typeLabel => returnType == ReturnType.salesReturn ? 'مرتجع مبيعات عميل' : 'مرتجع توريد مورد';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_number': returnNumber,
      'return_type': returnType == ReturnType.salesReturn ? 'sales' : 'purchase',
      'party_name': partyName,
      'date': date,
      'refund_method': refundMethod,
      'notes': notes,
      'total_amount': totalAmount,
    };
  }

  factory ReturnInvoiceModel.fromMap(Map<String, dynamic> map, List<ReturnItemModel> items) {
    return ReturnInvoiceModel(
      id: map['id'] ?? '',
      returnNumber: map['return_number'] ?? '',
      returnType: map['return_type'] == 'sales' ? ReturnType.salesReturn : ReturnType.purchaseReturn,
      partyName: map['party_name'] ?? 'عام',
      date: map['date'] ?? '',
      refundMethod: map['refund_method'] ?? 'خصم من الحساب',
      notes: map['notes'] ?? '',
      items: items,
    );
  }
}
