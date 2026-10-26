import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cloud_auth_service.dart';
import 'mongodb_sync_service.dart';
import 'offline_outbox_service.dart';

/// Cross-Warehouse availability result for BENAA centralized catalog
class CrossWarehouseResult {
  final String productId;
  final String productName;
  final String sku;
  final String primaryUnit;
  final Map<String, dynamic>? currentWarehouse;
  final List<WarehouseStockAvailability> otherWarehouses;
  final WarehouseStockAvailability? bestMatch;
  final String discoveryMessage;

  CrossWarehouseResult({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.primaryUnit,
    this.currentWarehouse,
    required this.otherWarehouses,
    this.bestMatch,
    required this.discoveryMessage,
  });

  factory CrossWarehouseResult.fromJson(Map<String, dynamic> json) {
    final prod = json['product'] as Map<String, dynamic>? ?? {};
    final othersList = (json['otherWarehouses'] as List<dynamic>? ?? [])
        .map((e) => WarehouseStockAvailability.fromJson(e as Map<String, dynamic>))
        .toList();

    WarehouseStockAvailability? best;
    if (json['bestMatch'] != null) {
      best = WarehouseStockAvailability.fromJson(json['bestMatch'] as Map<String, dynamic>);
    }

    return CrossWarehouseResult(
      productId: prod['id']?.toString() ?? '',
      productName: prod['name']?.toString() ?? '',
      sku: prod['sku']?.toString() ?? '',
      primaryUnit: prod['primaryUnit']?.toString() ?? 'وحدة',
      currentWarehouse: json['currentWarehouse'] as Map<String, dynamic>?,
      otherWarehouses: othersList,
      bestMatch: best,
      discoveryMessage: json['discoveryMessage']?.toString() ?? '',
    );
  }
}

class WarehouseStockAvailability {
  final String warehouseId;
  final String warehouseName;
  final String warehouseCode;
  final double stock;
  final double reserved;
  final double available;

  WarehouseStockAvailability({
    required this.warehouseId,
    required this.warehouseName,
    required this.warehouseCode,
    required this.stock,
    required this.reserved,
    required this.available,
  });

  factory WarehouseStockAvailability.fromJson(Map<String, dynamic> json) {
    return WarehouseStockAvailability(
      warehouseId: json['warehouseId']?.toString() ?? '',
      warehouseName: json['warehouseName']?.toString() ?? '',
      warehouseCode: json['warehouseCode']?.toString() ?? '',
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      reserved: (json['reserved'] as num?)?.toDouble() ?? 0.0,
      available: (json['available'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Transfer record with full 6-stage lifecycle
class LifecycleTransfer {
  final String id;
  final String transferNumber;
  final String productId;
  final String productName;
  final String productSku;
  final String fromWarehouseId;
  final String fromWarehouseName;
  final String toWarehouseId;
  final String toWarehouseName;
  final double requestedQuantity;
  final double? receivedQuantity;
  final String status; // REQUESTED, APPROVED, DISPATCHED, IN_TRANSIT, RECEIVED, COMPLETED, CANCELLED
  final String? requestedBy;
  final String? approvedBy;
  final String? dispatchedBy;
  final String? receivedBy;
  final String? requestedAt;
  final String? approvedAt;
  final String? dispatchedAt;
  final String? receivedAt;
  final String? notes;
  final String? discrepancyNotes;
  final List<dynamic>? auditHistory;

  LifecycleTransfer({
    required this.id,
    required this.transferNumber,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.fromWarehouseId,
    required this.fromWarehouseName,
    required this.toWarehouseId,
    required this.toWarehouseName,
    required this.requestedQuantity,
    this.receivedQuantity,
    required this.status,
    this.requestedBy,
    this.approvedBy,
    this.dispatchedBy,
    this.receivedBy,
    this.requestedAt,
    this.approvedAt,
    this.dispatchedAt,
    this.receivedAt,
    this.notes,
    this.discrepancyNotes,
    this.auditHistory,
  });

  String get arabicStatus {
    switch (status) {
      case 'REQUESTED':
        return 'مطلوب (بانتظار الموافقة)';
      case 'APPROVED':
        return 'معتمد ومحجوز';
      case 'DISPATCHED':
        return 'تم الإرسال';
      case 'IN_TRANSIT':
        return 'قيد النقل للشحنة';
      case 'RECEIVED':
        return 'تم الاستلام';
      case 'COMPLETED':
        return 'مكتمل ومرحّل';
      case 'CANCELLED':
        return 'ملغي';
      default:
        return status;
    }
  }

  factory LifecycleTransfer.fromJson(Map<String, dynamic> json) {
    final prod = json['product'] as Map<String, dynamic>? ?? {};
    final fromWh = json['fromWarehouse'] as Map<String, dynamic>? ?? {};
    final toWh = json['toWarehouse'] as Map<String, dynamic>? ?? {};

    return LifecycleTransfer(
      id: json['id']?.toString() ?? '',
      transferNumber: json['transferNumber']?.toString() ?? '',
      productId: json['productId']?.toString() ?? prod['id']?.toString() ?? '',
      productName: prod['name']?.toString() ?? 'منتج غير محدد',
      productSku: prod['sku']?.toString() ?? '',
      fromWarehouseId: json['fromWarehouseId']?.toString() ?? '',
      fromWarehouseName: fromWh['name']?.toString() ?? json['fromWarehouseId']?.toString() ?? '',
      toWarehouseId: json['toWarehouseId']?.toString() ?? '',
      toWarehouseName: toWh['name']?.toString() ?? json['toWarehouseId']?.toString() ?? '',
      requestedQuantity: (json['requestedQuantity'] as num?)?.toDouble() ?? 0.0,
      receivedQuantity: (json['receivedQuantity'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'REQUESTED',
      requestedBy: json['requestedBy']?.toString(),
      approvedBy: json['approvedBy']?.toString(),
      dispatchedBy: json['dispatchedBy']?.toString(),
      receivedBy: json['receivedBy']?.toString(),
      requestedAt: json['requestedAt']?.toString() ?? json['createdAt']?.toString(),
      approvedAt: json['approvedAt']?.toString(),
      dispatchedAt: json['dispatchedAt']?.toString(),
      receivedAt: json['receivedAt']?.toString(),
      notes: json['notes']?.toString(),
      discrepancyNotes: json['discrepancyNotes']?.toString(),
      auditHistory: json['auditHistory'] as List<dynamic>?,
    );
  }
}

/// BENAA Multi-Warehouse Service
class BenaaWarehouseService {
  static final List<String> _apiBases = [
    'http://localhost:3002',
    'http://127.0.0.1:3002',
    'http://localhost:3000',
    'http://10.0.2.2:3002',
  ];

  static Future<http.Response?> _getWithFallback(String path) async {
    for (final base in _apiBases) {
      try {
        final uri = Uri.parse('$base$path');
        final res = await http.get(uri, headers: await CloudAuthService.authenticatedHeaders()).timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) return res;
      } catch (_) {}
    }
    return null;
  }

  static Future<http.Response?> _postWithFallback(String path, Map<String, dynamic> body) async {
    for (final base in _apiBases) {
      try {
        final uri = Uri.parse('$base$path');
        final res = await http
            .post(
              uri,
              headers: await CloudAuthService.authenticatedHeaders(),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 4));
        if (res.statusCode >= 200 && res.statusCode < 300) return res;
      } catch (_) {}
    }
    return null;
  }

  static Future<Map<String, dynamic>> submitOperation(Map<String, dynamic> payload,
    {String operationType = 'TRANSFER_LIFECYCLE'}) async {
    await CloudAuthService.refreshCurrentSession();
    final operation = await OfflineOutboxService.instance.enqueue(payload, operationType: operationType);
    await OfflineOutboxService.instance.synchronize(endpoint: Uri.parse(MongoDbSyncService.apiBase),
      token: await CloudAuthService.sessionToken());
    final records = await OfflineOutboxService.instance.records();
    final state = records.firstWhere((row) => row['operationId'] == operation['operationId']);
    return {'success': state['state'] == 'applied', 'queued': state['state'] == 'queued',
      'operationId': operation['operationId'], 'error': state['error'],
      'message': state['state'] == 'applied' ? 'تم اعتماد العملية من الخادم' :
        state['state'] == 'queued' ? 'حُفظت العملية محلياً وبانتظار المزامنة' : 'تعارض يحتاج مراجعة؛ العملية محفوظة'};
  }

  /// Discovers stock across other warehouses in BENAA
  static Future<CrossWarehouseResult?> discoverCrossWarehouseStock({
    required String skuOrProductId,
    String? currentWarehouseId,
  }) async {
    final whId = currentWarehouseId ?? CloudAuthService.currentUser?.primaryWarehouseId ?? '';
    final path = '/api/inventory/cross-warehouse?sku=${Uri.encodeComponent(skuOrProductId)}&currentWarehouseId=${Uri.encodeComponent(whId)}';

    final res = await _getWithFallback(path);
    if (res != null) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return CrossWarehouseResult.fromJson(data);
      } catch (e) {
        print('Error decoding cross-warehouse response: $e');
      }
    }
    return null;
  }

  /// Requests a stock transfer from another warehouse
  static Future<Map<String, dynamic>> requestTransfer({
    required String productId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required double quantity,
    String? notes,
  }) async {
    final user = CloudAuthService.currentUser;
    final body = {
      'action': 'REQUEST',
      'productId': productId,
      'fromWarehouseId': fromWarehouseId,
      'toWarehouseId': toWarehouseId,
      'quantity': quantity,
      'notes': notes ?? 'طلب تحويل تلقائي لسد العجز عبر تطبيق بناء',
    };

    return submitOperation(body);
  }

  /// Advances or completes a transfer in the 6-stage lifecycle
  static Future<Map<String, dynamic>> executeLifecycleAction({
    required String transferId,
    required String action, // APPROVE, DISPATCH, RECEIVE, CANCEL
    double? receivedQuantity,
    String? cancellationReason,
    String? discrepancyNotes,
  }) async {
    final user = CloudAuthService.currentUser;
    final body = {
      'action': action,
      'transferId': transferId,
      'receivedQuantity': receivedQuantity,
      'cancellationReason': cancellationReason,
      'discrepancyNotes': discrepancyNotes,
    };

    return submitOperation(body);
  }

  /// Fetches transfers from the lifecycle endpoint
  static Future<List<LifecycleTransfer>> fetchLifecycleTransfers({
    String? warehouseId,
    String? status,
  }) async {
    final user = CloudAuthService.currentUser;
    final whId = warehouseId ?? user?.primaryWarehouseId ?? '';
    final role = user?.role ?? 'SUPER_ADMIN';

    var path = '/api/inventory/transfers/lifecycle?warehouseId=${Uri.encodeComponent(whId)}&userRole=${Uri.encodeComponent(role)}';
    if (status != null && status.isNotEmpty) {
      path += '&status=${Uri.encodeComponent(status)}';
    }

    final res = await _getWithFallback(path);
    if (res != null) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final transfersList = data['transfers'] as List<dynamic>? ?? [];
        return transfersList.map((e) => LifecycleTransfer.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        print('Error decoding lifecycle transfers: $e');
      }
    }
    return [];
  }
}
