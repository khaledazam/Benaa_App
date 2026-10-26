import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:benaa_flutter_mobile/core/services/cloud_auth_service.dart';
import 'package:benaa_flutter_mobile/presentation/screens/projects_screen.dart';

void main() {
  for (final width in [320.0, 800.0]) {
    testWidgets('PROJECT-UI-$width scoped quantity report renders without overflow or financial fields', (tester) async {
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({}); await CloudAuthService.logout();
        tester.view.physicalSize = Size(width, 720); tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: ProjectsScreen())));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.textContaining('سند-1'), 150);
        expect(find.textContaining('مشروع اختبار'), findsOneWidget);
        expect(find.textContaining('سند-1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('ضريبة'), findsNothing);
        expect(find.textContaining('مديونية'), findsNothing);
      }, () => MockClient((request) async => http.Response(jsonEncode(request.url.path == '/api/projects' ? {
        'projects': [{'id': 'project', 'name': 'مشروع اختبار'}],
      } : {'issues': [{'id': 'issue', 'issueNumber': 'سند-1', 'projectId': 'project', 'status': 'RESERVED',
        'items': [{'id': 'line', 'productId': 'product', 'quantity': 10, 'reservedQuantity': 10,
          'remainingQuantity': 10, 'dispatchedQuantity': 0, 'returnedQuantity': 0}]}]}), 200, encoding: utf8)));
    });
  }
  testWidgets('PROJECT-UI partial dispatch is a durable server operation without customer invoice fields', (tester) async {
    Map<String, dynamic>? sent;
    final user = {'id': 'project-user', 'name': 'Audit', 'email': 'audit@example.invalid',
      'role': 'STOREKEEPER', 'status': true, 'primaryWarehouseId': 'warehouse-a', 'warehouseIds': ['warehouse-a']};
    await http.runWithClient(() async {
      SharedPreferences.setMockInitialValues({'benaa_current_user_json': jsonEncode(user), 'benaa_session_token': 'fixture-token'});
      await CloudAuthService.initialize();
      await tester.pumpWidget(const MaterialApp(home: ProjectsScreen())); await tester.pumpAndSettle();
      await tester.tap(find.text('DISPATCH')); await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '2');
      await tester.tap(find.text('إرسال للاعتماد')); await tester.pumpAndSettle();
      expect(sent!['operationType'], 'MATERIAL_ISSUE_LIFECYCLE');
      expect(sent!['actorId'], 'project-user'); expect(sent!['warehouseId'], 'warehouse-a');
      final payload = sent!['payload'] as Map;
      expect(payload['action'], 'DISPATCH'); expect(payload['issueId'], 'issue');
      expect(payload['quantities'], [{'issueItemId': 'line', 'quantity': 2.0}]);
      expect(payload.containsKey('customerId'), isFalse); expect(payload.containsKey('totalAmount'), isFalse);
      expect(tester.takeException(), isNull);
      await CloudAuthService.logout();
    }, () => MockClient((request) async {
      if (request.url.path == '/api/auth/session') return http.Response(jsonEncode(user), 200);
      if (request.method == 'POST' && request.url.path == '/api/mobile-sync') {
        sent = jsonDecode(request.body);
        expect(request.headers['authorization'], 'Bearer fixture-token');
        return http.Response(jsonEncode({'success': true, 'operationId': sent!['operationId'], 'issue': {'id': 'issue'}}), 200);
      }
      if (request.url.path == '/api/projects') return http.Response('{"projects":[{"id":"project","name":"Audit"}]}', 200);
      if (request.url.path == '/api/projects/material-issues') return http.Response(jsonEncode({'issues': [{
        'id': 'issue', 'issueNumber': 'ISSUE-1', 'projectId': 'project', 'status': 'RESERVED',
        'items': [{'id': 'line', 'productId': 'product', 'quantity': 10, 'reservedQuantity': 10,
          'remainingQuantity': 10, 'dispatchedQuantity': 0, 'returnedQuantity': 0}]}]}), 200);
      return http.Response('{}', 403);
    }));
  });
}
