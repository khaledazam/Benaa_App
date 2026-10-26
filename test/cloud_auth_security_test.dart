import 'dart:convert';

import 'package:benaa_flutter_mobile/core/services/cloud_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CloudAuthService.logout();
  });

  test('SEC-FL-01 privileged identity cannot bypass backend authentication', () async {
    var requests = 0;
    await http.runWithClient(() async {
      final result = await CloudAuthService.loginWithCredentials(
        identifier: 'khaled-audit-only', password: 'wrong-audit-password');
      expect(result['success'], isFalse);
      expect(CloudAuthService.isLoggedIn, isFalse);
    }, () => MockClient((request) async {
      requests++;
      return http.Response(jsonEncode({'error': 'Invalid credentials'}), 401);
    }));
    expect(requests, 1);
  });

  test('SEC-FL-02 cached employee cannot authenticate with an arbitrary password', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('benaa_cached_company_users', jsonEncode([{
      'id': 'audit-user', 'name': 'Audit Fixture', 'email': 'audit@example.invalid',
      'username': 'audit-user', 'role': 'STOREKEEPER', 'status': true,
      'isSubscriptionActive': true,
    }]));
    await http.runWithClient(() async {
      await CloudAuthService.initialize();
      final result = await CloudAuthService.loginWithCredentials(
        identifier: 'audit-user', password: 'incorrect');
      expect(result['success'], isFalse);
      expect(CloudAuthService.isLoggedIn, isFalse);
    }, () => MockClient((request) async => http.Response('{}', 503)));
  });

  test('SEC-FL-03 backend rejection cannot create a cached session', () async {
    await http.runWithClient(() async {
      final result = await CloudAuthService.loginWithCredentials(
        identifier: 'audit@example.invalid', password: 'incorrect');
      expect(result['success'], isFalse);
      expect(CloudAuthService.currentUser, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('benaa_current_user_json'), isNull);
    }, () => MockClient((request) async => http.Response('{"error":"Forbidden"}', 403)));
  });

  test('SEC-FL-04 rejected warehouse creation is not reported as success', () async {
    final count = CloudAuthService.cachedWarehouses.length;
    await http.runWithClient(() async {
      expect(await CloudAuthService.provisionNewWarehouse(
        name: 'Audit only', code: 'AUDIT'), isFalse);
    }, () => MockClient((request) async => http.Response('{}', 403)));
    expect(CloudAuthService.cachedWarehouses.length, count);
  });

  test('SEC-FL-05 rejected employee creation is not reported as success', () async {
    await http.runWithClient(() async {
      expect(await CloudAuthService.provisionNewUser(
        name: 'Audit only', email: 'audit@example.invalid', username: 'audit',
        password: 'test-fixture-only', role: CompanyUserRole.storekeeper,
        primaryWarehouseId: 'audit-wh', subscriptionStartDate: '2026-01-01',
        subscriptionEndDate: '2027-01-01'), isFalse);
    }, () => MockClient((request) async => http.Response('{}', 403)));
  });

  test('SEC-FL-06 rejected reassignment is not reported as success', () async {
    await http.runWithClient(() async {
      expect(await CloudAuthService.reassignEmployeeWarehouse(
        employeeId: 'audit-user', newPrimaryWarehouseId: 'audit-wh'), isFalse);
    }, () => MockClient((request) async => http.Response('{}', 403)));
  });
}
