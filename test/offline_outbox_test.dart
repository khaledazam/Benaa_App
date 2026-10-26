import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:benaa_flutter_mobile/core/services/local_scope_service.dart';
import 'package:benaa_flutter_mobile/core/services/offline_outbox_service.dart';

void main() {
  final endpoint = Uri.parse('https://audit.invalid/api/mobile-sync');
  setUp(() { SharedPreferences.setMockInitialValues({}); LocalScopeService.select('employee-a', 'warehouse-a'); });
  tearDown(() => LocalScopeService.select(null, null));
  test('OUT-01 persists stable UUID across new instance and network timeout retry', () async {
    var box = OfflineOutboxService();
    final operation = await box.enqueue({'action': 'APPROVE', 'transferId': 'fixture'});
    final id = operation['operationId'];
    expect(id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    await box.synchronize(endpoint: endpoint, token: 'fixture-token', client: MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer fixture-token');
      throw http.ClientException('Simulated timeout');
    }));
    box = OfflineOutboxService();
    expect((await box.records()).single['state'], 'queued');
    await box.synchronize(endpoint: endpoint, token: 'fixture-token', client: MockClient((request) async {
      final body = jsonDecode(request.body);
      expect(body['operationId'], id);
      expect(body['actorId'], 'employee-a');
      expect(body['warehouseId'], 'warehouse-a');
      return http.Response(jsonEncode({'success': true, 'operationId': id, 'replayed': true}), 200);
    }));
    final receipt = (await box.records()).single;
    expect(receipt['state'], 'applied'); expect(receipt['attempts'], 2);
  });
  test('OUT-02 accounts isolated and logout never deletes pending operations', () async {
    final box = OfflineOutboxService();
    await box.enqueue({'action': 'REQUEST'});
    LocalScopeService.select(null, null); expect(await box.records(), isEmpty);
    LocalScopeService.select('employee-b', 'warehouse-a'); expect(await box.records(), isEmpty);
    LocalScopeService.select('employee-a', 'warehouse-a'); expect((await box.records()).single['state'], 'queued');
  });
  test('OUT-03 reassignment retains old commands as conflict without sending', () async {
    final box = OfflineOutboxService();
    final original = await box.enqueue({'action': 'REQUEST'});
    LocalScopeService.select('employee-a', 'warehouse-b');
    var calls = 0;
    await box.synchronize(endpoint: endpoint, token: 'fixture-token', client: MockClient((request) async {
      calls++; return http.Response('{}', 500);
    }));
    final entry = (await box.records()).single;
    expect(calls, 0); expect(entry['state'], 'conflict'); expect(entry['operationId'], original['operationId']);
    await expectLater(box.retryAfterReview(entry['operationId']), throwsStateError);
  });
  for (final status in [401, 403, 409, 422]) {
    test('OUT-$status server conflict retained and blocks later dependent operations', () async {
      final box = OfflineOutboxService();
      await box.enqueue({'action': 'APPROVE'});
      await box.enqueue({'action': 'DISPATCH'});
      var calls = 0;
      final client = MockClient((request) async { calls++; return http.Response('{}', status); });
      await box.synchronize(endpoint: endpoint, token: 'fixture-token', client: client);
      await box.synchronize(endpoint: endpoint, token: 'fixture-token', client: client);
      final entries = await box.records();
      expect(entries.first['state'], 'conflict'); expect(entries.last['state'], 'queued'); expect(calls, 1);
    });
  }
  test('OUT-04 crash inflight is retried with same UUID; project type is preserved', () async {
    final box = OfflineOutboxService();
    final operation = await box.enqueue({'action': 'CREATE', 'items': []}, operationType: 'MATERIAL_ISSUE_LIFECYCLE');
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getStringList('benaa_outbox_scopes_employee-a')!.single;
    await prefs.setString(key, jsonEncode([{...operation, 'state': 'inflight'}]));
    await OfflineOutboxService().synchronize(endpoint: endpoint, token: 'fixture-token', client: MockClient((request) async {
      final body = jsonDecode(request.body);
      expect(body['operationId'], operation['operationId']); expect(body['operationType'], 'MATERIAL_ISSUE_LIFECYCLE');
      return http.Response(jsonEncode({'success': true, 'operationId': operation['operationId']}), 200);
    }));
    expect((await box.records()).single['state'], 'applied');
  });
  test('OUT-05 duplicate sync calls send one command and retain acknowledged receipt', () async {
    final box = OfflineOutboxService(); final operation = await box.enqueue({'action': 'REQUEST'});
    var calls = 0;
    final client = MockClient((request) async { calls++; return http.Response(jsonEncode({'success': true, 'operationId': operation['operationId']}), 200); });
    await Future.wait([box.synchronize(endpoint: endpoint, token: 'fixture-token', client: client), box.synchronize(endpoint: endpoint, token: 'fixture-token', client: client)]);
    await box.synchronize(endpoint: endpoint, token: 'fixture-token', client: client);
    expect(calls, 1); expect((await box.records()).single['receipt'], isNotNull);
  });
}
