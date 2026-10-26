import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'local_scope_service.dart';

/// Durable commands, never stock snapshots. Applied records are retained as
/// receipts; conflicts require review and are never silently discarded/rekeyed.
class OfflineOutboxService {
  static final OfflineOutboxService instance = OfflineOutboxService();
  Future<void> _writes = Future.value();
  bool _syncing = false;
  static String _key(String actor, String warehouse) =>
      'benaa_outbox_v1_${base64Url.encode(utf8.encode('$actor:$warehouse'))}';
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<Map<String, dynamic>>> records() async {
    await _writes;
    final actor = LocalScopeService.actorId;
    if (actor == null) return [];
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList('benaa_outbox_scopes_$actor') ?? [];
    return keys.expand((key) {
      final raw = prefs.getString(key);
      return raw == null ? <Map<String, dynamic>>[] :
        (jsonDecode(raw) as List).map((entry) => Map<String, dynamic>.from(entry));
    }).toList();
  }

  Future<Map<String, dynamic>> enqueue(Map<String, dynamic> payload,
    {String operationType = 'TRANSFER_LIFECYCLE'}) => _serialized(() async {
    final actor = LocalScopeService.actorId;
    final warehouse = LocalScopeService.warehouseId;
    if (actor == null || warehouse == null || warehouse.isEmpty) {
      throw StateError('An authenticated warehouse assignment is required');
    }
    final prefs = await SharedPreferences.getInstance();
    final key = _key(actor, warehouse);
    final entries = (jsonDecode(prefs.getString(key) ?? '[]') as List)
        .map((entry) => Map<String, dynamic>.from(entry)).toList();
    final operation = <String, dynamic>{
      'operationId': const Uuid().v4(), 'actorId': actor, 'warehouseId': warehouse,
      'operationType': operationType,
      'payload': jsonDecode(jsonEncode(payload)), 'state': 'queued',
      'attempts': 0, 'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    entries.add(operation);
    final keys = prefs.getStringList('benaa_outbox_scopes_$actor') ?? [];
    // Register before queue write: an empty registered scope is harmless;
    // a successfully persisted operation must always remain discoverable.
    if (!keys.contains(key)) {
      await prefs.setStringList('benaa_outbox_scopes_$actor', [...keys, key]);
    }
    if (!await prefs.setString(key, jsonEncode(entries))) {
      throw StateError('Unable to persist offline operation');
    }
    return Map<String, dynamic>.from(operation);
  });

  Future<void> _update(Map<String, dynamic> operation) => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(operation['actorId'], operation['warehouseId']);
    final entries = (jsonDecode(prefs.getString(key) ?? '[]') as List)
        .map((entry) => Map<String, dynamic>.from(entry)).toList();
    final index = entries.indexWhere((entry) => entry['operationId'] == operation['operationId']);
    if (index < 0) throw StateError('Persisted operation is missing');
    entries[index] = operation;
    if (!await prefs.setString(key, jsonEncode(entries))) {
      throw StateError('Unable to persist operation status');
    }
  });

  Future<void> retryAfterReview(String operationId) async {
    final operation = (await records()).firstWhere((entry) => entry['operationId'] == operationId);
    if (operation['actorId'] != LocalScopeService.actorId ||
        operation['warehouseId'] != LocalScopeService.warehouseId) {
      throw StateError('Old warehouse operation requires authorized warehouse review');
    }
    if (operation['state'] == 'applied') return;
    operation['state'] = 'queued';
    operation.remove('error');
    await _update(operation);
  }

  Future<void> synchronize({required Uri endpoint, required String? token,
    http.Client? client}) async {
    if (_syncing) return;
    _syncing = true;
    final transport = client ?? http.Client();
    try {
      final actor = LocalScopeService.actorId;
      final warehouse = LocalScopeService.warehouseId;
      if (actor == null) return;
      for (final operation in await records()) {
        if (LocalScopeService.actorId != actor || LocalScopeService.warehouseId != warehouse) break;
        if (operation['state'] == 'applied') continue;
        if (operation['state'] == 'conflict') {
          if (operation['warehouseId'] == warehouse) break;
          continue;
        }
        if (operation['warehouseId'] != warehouse || token == null || token.isEmpty) {
          operation['state'] = 'conflict';
          operation['error'] = operation['warehouseId'] != warehouse
              ? 'Warehouse assignment changed; review and reauthorization required'
              : 'Authentication required; operation retained for review';
          await _update(operation);
          continue;
        }
        // A persisted inflight command after a crash is retried with the SAME ID.
        operation['state'] = 'inflight';
        operation['attempts'] = (operation['attempts'] as int) + 1;
        await _update(operation);
        try {
          final response = await transport.post(endpoint,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({
              'action': 'sync_operation',
              for (final field in ['operationId', 'actorId', 'warehouseId', 'operationType', 'payload'])
                field: operation[field],
            })).timeout(const Duration(seconds: 15));
          final body = jsonDecode(response.body);
          if (response.statusCode == 200 && body is Map && body['success'] == true &&
              body['operationId'] == operation['operationId']) {
            operation['state'] = 'applied';
            operation['receipt'] = body;
            operation.remove('error');
          } else if (response.statusCode >= 400 && response.statusCode < 500) {
            operation['state'] = 'conflict';
            operation['error'] = 'Server rejected operation (HTTP ${response.statusCode}); review required';
          } else {
            operation['state'] = 'queued';
            operation['error'] = 'Server unavailable or invalid acknowledgement; retry retained';
          }
        } catch (_) {
          operation['state'] = 'queued';
          operation['error'] = 'Connection interrupted; retry retained with the same operation ID';
        }
        await _update(operation);
        // Preserve causal order after a timeout or conflict. A dependent action
        // must not pass an earlier command whose outcome is uncertain.
        if (operation['state'] != 'applied') break;
      }
    } finally {
      _syncing = false;
      if (client == null) transport.close();
    }
  }
}
