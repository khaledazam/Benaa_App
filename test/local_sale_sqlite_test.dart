import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:benaa_flutter_mobile/core/database/db_helper.dart';
import 'package:benaa_flutter_mobile/core/services/local_scope_service.dart';

void main() {
  final db = DBHelper();
  late Directory temporary;
  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('benaa-isolated-sqlite-');
    sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(temporary.path);
  });
  setUp(() async {
    await db.close(); LocalScopeService.select('sqlite-audit', 'warehouse-a');
    expect(await db.database, isNotNull, reason: 'This test must exercise real SQLite, not fallback memory');
    await db.clearAllDatabaseData();
    await db.registerOrUpdateLocalItem(code: 'product', name: 'Audit', category: 'Audit', unit: 'piece', initialQty: 100);
  });
  tearDownAll(() async { await db.close(); LocalScopeService.select(null, null); await temporary.delete(recursive: true); });
  Map<String, dynamic> line(double qty, {String code = 'product', double? base}) =>
    {'item_code': code, 'item_name': 'Audit', 'qty': qty, 'base_qty': base ?? qty, 'unit_price': 1.0};
  test('SQL-01 base units, sale lines and movements commit together in SQLite', () async {
    await db.createSaleOrder('sale', 'INV', 'Audit', 2, [line(2, base: 24)]);
    expect((await db.getLocalItems()).single.currentStock, 76);
    final native = (await db.database)!;
    expect((await native.query('sale_items')).single['base_qty'], 24);
    expect((await native.query('stock_movements')).single['base_quantity'], 24);
    await db.close(); expect((await db.getLocalItems()).single.currentStock, 76);
  });
  test('SQL-02 failed later line rolls back prior deduction, invoice and movements', () async {
    await expectLater(db.createSaleOrder('sale', 'INV', 'Audit', 2, [line(2), line(1, code: 'missing')]), throwsStateError);
    final native = (await db.database)!;
    expect((await db.getLocalItems()).single.currentStock, 100);
    expect(await native.query('sales'), isEmpty); expect(await native.query('sale_items'), isEmpty);
    expect(await native.query('stock_movements'), isEmpty);
  });
  test('SQL-03 parallel demands cannot oversell SQLite stock', () async {
    final outcomes = await Future.wait([70.0, 50.0].asMap().entries.map((entry) async {
      try { await db.createSaleOrder('sale-${entry.key}', 'INV', 'Audit', entry.value, [line(entry.value)]); return true; }
      on StateError { return false; }
    }));
    expect(outcomes.where((entry) => entry), hasLength(1));
    expect((await db.getLocalItems()).single.currentStock, anyOf(30, 50));
    expect(await (await db.database)!.query('sales'), hasLength(1));
  });
}
