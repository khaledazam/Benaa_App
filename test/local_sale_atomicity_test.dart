import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:benaa_flutter_mobile/core/database/db_helper.dart';
import 'package:benaa_flutter_mobile/core/services/local_scope_service.dart';
import 'package:benaa_flutter_mobile/data/models/customer_model.dart';

void main() {
  final db = DBHelper();
  setUp(() async {
    await db.close(); SharedPreferences.setMockInitialValues({});
    LocalScopeService.select('sale-audit', 'warehouse-a');
    await db.clearAllDatabaseData();
    await db.registerOrUpdateLocalItem(code: 'product', name: 'Audit', category: 'Audit', unit: 'piece', initialQty: 100);
  });
  tearDown(() async { await db.close(); LocalScopeService.select(null, null); });
  Map<String, dynamic> line(double qty, {String code = 'product', double? base}) =>
    {'item_code': code, 'item_name': 'Audit', 'qty': qty, 'base_qty': base ?? qty, 'unit_price': 1.0};
  test('SALE-01 package base quantity controls exact deduction and movement', () async {
    await db.createSaleOrder('sale', 'INV', 'Customer', 2, [line(2, base: 24)]);
    expect((await db.getLocalItems()).single.currentStock, 76);
    expect((await db.getStockMovements('product')).single.baseQuantity, 24);
  });
  test('SALE-02 insufficient stock rejects all lines and customer debt', () async {
    await expectLater(db.createSaleOrder('sale', 'INV', 'Customer', 102, [line(2), line(100)]), throwsStateError);
    expect((await db.getLocalItems()).single.currentStock, 100);
    expect(await db.getSalesForCustomer('Customer'), isEmpty);
    expect(CustomerModel.sampleCustomers, isEmpty);
    expect(await db.getStockMovements('product'), isEmpty);
  });
  test('SALE-03 concurrent competition permits one exact sale', () async {
    final results = await Future.wait([70.0, 50.0].asMap().entries.map((entry) async {
      try { await db.createSaleOrder('sale-${entry.key}', 'INV', 'Customer', entry.value, [line(entry.value)]); return true; }
      on StateError { return false; }
    }));
    expect(results.where((value) => value), hasLength(1));
    expect((await db.getLocalItems()).single.currentStock, anyOf(30, 50));
    expect(await db.getStockMovements('product'), hasLength(1));
  });
  test('SALE-04 first read and true local reopen preserve stock and history', () async {
    expect((await db.getLocalItems()).single.code, 'product');
    await db.createSaleOrder('sale', 'INV', 'Customer', 2, [line(2)]);
    await db.close();
    expect((await db.getLocalItems()).single.currentStock, 98);
    expect(await db.getSalesForCustomer('Customer'), hasLength(1));
    expect(await db.getStockMovements('product'), hasLength(1));
  });
  test('SALE-05 employee and reassigned warehouse storage are isolated without deleting old records', () async {
    LocalScopeService.select('other-employee', 'warehouse-a'); expect(await db.getLocalItems(), isEmpty);
    LocalScopeService.select('sale-audit', 'warehouse-b'); expect(await db.getLocalItems(), isEmpty);
    LocalScopeService.select('sale-audit', 'warehouse-a'); expect((await db.getLocalItems()).single.currentStock, 100);
  });
  test('SALE-06 invalid and duplicate operations do not partially post', () async {
    await expectLater(db.createSaleOrder('bad', 'INV', 'Customer', 1, [line(double.nan)]), throwsArgumentError);
    await db.createSaleOrder('sale', 'INV', 'Customer', 2, [line(2)]);
    await expectLater(db.createSaleOrder('sale', 'INV', 'Customer', 2, [line(2)]), throwsStateError);
    expect((await db.getLocalItems()).single.currentStock, 98);
    expect(await db.getStockMovements('product'), hasLength(1));
  });
}
