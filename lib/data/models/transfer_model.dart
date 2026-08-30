class TransferItemModel {
  final int? id;
  final String transferId;
  final String itemCode;
  final String itemName;
  final String author;
  final double expectedQty;
  double actualQty;
  String? notes;
  String? imagePath;

  TransferItemModel({
    this.id,
    required this.transferId,
    required this.itemCode,
    required this.itemName,
    required this.author,
    required this.expectedQty,
    required this.actualQty,
    this.notes,
    this.imagePath,
  });

  double get discrepancy => actualQty - expectedQty;
  bool get hasDiscrepancy => actualQty != expectedQty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transfer_id': transferId,
      'item_code': itemCode,
      'item_name': itemName,
      'author': author,
      'expected_qty': expectedQty,
      'actual_qty': actualQty,
      'notes': notes,
      'image_path': imagePath,
    };
  }

  factory TransferItemModel.fromMap(Map<String, dynamic> map) {
    return TransferItemModel(
      id: map['id'],
      transferId: map['transfer_id'] ?? '',
      itemCode: map['item_code']?.toString() ?? '',
      itemName: map['item_name'] ?? '',
      author: map['author'] ?? 'MOHAMED',
      expectedQty: (map['expected_qty'] as num?)?.toDouble() ?? 0.0,
      actualQty: (map['actual_qty'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      imagePath: map['image_path'],
    );
  }
}

class TransferModel {
  final String id;
  final String transferNumber;
  final String fromWarehouse;
  final String toWarehouse;
  final String author;
  final String date;
  String status; // 'pending_audit', 'audited_matched', 'audited_discrepancy'
  final String? notes;
  List<TransferItemModel> items;

  TransferModel({
    required this.id,
    required this.transferNumber,
    required this.fromWarehouse,
    required this.toWarehouse,
    required this.author,
    required this.date,
    required this.status,
    this.notes,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transfer_number': transferNumber,
      'from_warehouse': fromWarehouse,
      'to_warehouse': toWarehouse,
      'author': author,
      'date': date,
      'status': status,
      'notes': notes,
    };
  }

  factory TransferModel.fromMap(Map<String, dynamic> map, {List<TransferItemModel>? items}) {
    return TransferModel(
      id: map['id'] ?? '',
      transferNumber: map['transfer_number']?.toString() ?? '',
      fromWarehouse: map['from_warehouse'] ?? '',
      toWarehouse: map['to_warehouse'] ?? '',
      author: map['author'] ?? '',
      date: map['date'] ?? '',
      status: map['status'] ?? 'pending_audit',
      notes: map['notes'],
      items: items ?? [],
    );
  }
}
