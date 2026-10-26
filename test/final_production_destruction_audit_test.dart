import 'package:flutter_test/flutter_test.dart';
import 'package:benaa_flutter_mobile/data/models/item_model.dart';
import 'package:benaa_flutter_mobile/data/models/product_unit_model.dart';
import 'package:benaa_flutter_mobile/data/models/customer_model.dart';
import 'package:benaa_flutter_mobile/core/database/db_helper.dart';
import 'package:benaa_flutter_mobile/core/services/unit_conversion_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Benaa Flutter — Final Production Destruction & Recovery Audit Suite', () {
    late DBHelper db;

    setUp(() async {
      db = DBHelper();
      await db.clearAllDatabaseData();
      CustomerModel.clearAllCustomers();
    });

    test('DESTRUCTION-01: Multi-Tap (10 Rapid Taps) Idempotency on Transfer Audit', () async {
      final tId = await db.createNewCustomTransfer(
        transferNumber: 'TRF-CHAOS-10X',
        fromWarehouse: 'مستودع جدة الرئيسي',
        toWarehouse: 'مستودع بريدة',
        author: 'فهد المطيري',
        notes: 'اختبار النقر المتعدد 10 مرات',
        items: [{'item_code': 'STEEL-12MM', 'item_name': 'حديد تسليح سابك 12 مم', 'qty': 50.0, 'notes': ''}],
      );

      await db.registerOrUpdateLocalItem(
        code: 'STEEL-12MM',
        name: 'حديد تسليح سابك 12 مم',
        category: 'حديد ومعادن',
        unit: 'طن',
        initialQty: 100.0,
      );

      // Simulate 10 concurrent / rapid taps on "Confirm Audit"
      await Future.wait(List.generate(10, (_) => db.confirmTransferAudit(tId, 'audited_matched')));

      final items = await db.getLocalItems();
      final steel = items.firstWhere((i) => i.code == 'STEEL-12MM');

      // MUST be exactly 150.0 (100 + 50), NOT 600.0 or 1000.0!
      expect(steel.currentStock, 150.0);
    });

    test('DESTRUCTION-02: Concurrent Operations against Same Stock (No Negative Inventory)', () async {
      // Available Stock = 100
      await db.registerOrUpdateLocalItem(
        code: 'MARBLE-ROYAL',
        name: 'رخام روزا برتغالي نخب أول',
        category: 'رخام',
        unit: 'م²',
        initialQty: 100.0,
        unitPrice: 220.0,
      );

      // Two concurrent sales: 70 m² and 50 m² (Total 120 m² > 100 available)
      await Future.wait([
        db.createSaleOrder('sale-c1', 'INV-C1', 'عميل 1', 15400.0, [
          {'item_code': 'MARBLE-ROYAL', 'item_name': 'رخام روزا برتغالي نخب أول', 'qty': 70.0, 'unit_price': 220.0, 'total': 15400.0}
        ]),
        expectLater(db.createSaleOrder('sale-c2', 'INV-C2', 'عميل 2', 11000.0, [
          {'item_code': 'MARBLE-ROYAL', 'item_name': 'رخام روزا برتغالي نخب أول', 'qty': 50.0, 'unit_price': 220.0, 'total': 11000.0}
        ]), throwsStateError),
      ]);

      final items = await db.getLocalItems();
      final marble = items.firstWhere((i) => i.code == 'MARBLE-ROYAL');

      // Clamped at >= 0 (no negative stock corruption)
      expect(marble.currentStock, 30.0);
      expect(await db.getSalesForCustomer('عميل 2'), isEmpty);
    });

    test('DESTRUCTION-03: 20x Continuous Transaction & App Restart Cycles', () async {
      const code = 'CEMENT-SULPHATE';
      await db.registerOrUpdateLocalItem(
        code: code,
        name: 'إسمنت مقاوم للأملاح والكبريتات 50 كجم',
        category: 'إسمنت',
        unit: 'كيس',
        initialQty: 1000.0,
        unitPrice: 30.0,
      );

      // Perform 20 sequential transactions with simulated app kills and reloads
      double runningStock = 1000.0;
      for (int cycle = 1; cycle <= 20; cycle++) {
        final reloadedDb = DBHelper();

        if (cycle % 2 == 1) {
          // Odd cycles: Sales deduction (-10)
          await reloadedDb.createSaleOrder(
            'sale-cycle-$cycle',
            'INV-CYC-$cycle',
            'مقاول دورة $cycle',
            300.0,
            [{'item_code': code, 'item_name': 'إسمنت مقاوم للأملاح والكبريتات 50 كجم', 'qty': 10.0, 'unit_price': 30.0, 'total': 300.0}],
          );
          runningStock -= 10.0;
        } else {
          // Even cycles: Goods Receipt (+15)
          final tId = await reloadedDb.createNewCustomTransfer(
            transferNumber: 'TRF-CYC-$cycle',
            fromWarehouse: 'المصنع',
            toWarehouse: 'مستودع بريدة',
            author: 'أمين المستودع',
            notes: '',
            items: [{'item_code': code, 'item_name': 'إسمنت مقاوم للأملاح والكبريتات 50 كجم', 'qty': 15.0, 'notes': ''}],
          );
          await reloadedDb.confirmTransferAudit(tId, 'audited_matched');
          runningStock += 15.0;
        }
      }

      // Net change: 10 sales * (-10) + 10 receipts * (+15) = -100 + 150 = +50
      // Expected = 1000 + 50 = 1050.0
      expect(runningStock, 1050.0);

      final finalDb = DBHelper();
      final items = await finalDb.getLocalItems();
      final cement = items.firstWhere((i) => i.code == code);
      expect(cement.currentStock, 1050.0);
    });

    test('DESTRUCTION-04: Extreme Quantities & Boundary Validation', () async {
      final item = ItemModel(
        code: 'MICRO-ITEM',
        name: 'مادة عزل مائي نانو ميكرون',
        category: 'عوازل',
        legacyUnit: 'لتر',
        currentStock: 1000000.0,
        units: [
          ProductUnitModel(id: 'u1', productCode: 'MICRO-ITEM', unitName: 'لتر', unitType: UnitType.volume, conversionFactor: 1.0, isBase: true),
          ProductUnitModel(id: 'u2', productCode: 'MICRO-ITEM', unitName: 'برميل', unitType: UnitType.packaging, conversionFactor: 200.0),
          ProductUnitModel(id: 'u3', productCode: 'MICRO-ITEM', unitName: 'مليلتر', unitType: UnitType.volume, conversionFactor: 0.001),
        ],
      );

      // Micro quantity (500 ml -> 0.5 L)
      final microBase = UnitConversionEngine.convertToBaseUnit(item: item, unitName: 'مليلتر', quantity: 500.0);
      expect(microBase, 0.5);

      // Zero quantity
      final zeroBase = UnitConversionEngine.convertToBaseUnit(item: item, unitName: 'برميل', quantity: 0.0);
      expect(zeroBase, 0.0);

      // Large enterprise quantity (5,000 Barrels -> 1,000,000 L)
      final largeBase = UnitConversionEngine.convertToBaseUnit(item: item, unitName: 'برميل', quantity: 5000.0);
      expect(largeBase, 1000000.0);

      // Reversibility check: 1,000,000 L -> Barrels -> 5000
      final revBarrels = UnitConversionEngine.convertFromBaseUnit(item: item, targetUnitName: 'برميل', baseQuantity: largeBase);
      expect(revBarrels, 5000.0);
    });

    test('DESTRUCTION-05: RTL & Long Arabic Strings Non-Destructive Storage', () async {
      const longCustomerName = 'شركة المحمدية العالمية المتحدة للمقاولات العامة والتشطيبات الفاخرة والديكور والتوريدات المسجلة';
      const longItemName = 'ألواح جرانيت نجران براون فاخر مقاس 60*120 سم سماكة 2 سم معالجة بالإيبوكسي المقاوم للأحماض والحرارة العالية';

      await db.registerOrUpdateLocalItem(
        code: 'GRANITE-LONG-01',
        name: longItemName,
        category: 'رخام وجرانيت',
        unit: 'م²',
        initialQty: 500.0,
        unitPrice: 195.0,
        location: 'معرض المواد الخام الكبرى - قاعة العرض الرئيسية - جناح 14 - رف A1',
      );

      await db.createSaleOrder(
        'sale-long-ar',
        'INV-LONG-ARABIC-001',
        longCustomerName,
        9750.0,
        [{'item_code': 'GRANITE-LONG-01', 'item_name': longItemName, 'qty': 50.0, 'unit_price': 195.0, 'total': 9750.0}],
      );

      final items = await db.getLocalItems();
      final granite = items.firstWhere((i) => i.code == 'GRANITE-LONG-01');
      expect(granite.name, longItemName);
      expect(granite.currentStock, 450.0);

      final sales = await db.getSalesForCustomer(longCustomerName);
      expect(sales.length, 1);
      expect(sales.first['invoice_number'], 'INV-LONG-ARABIC-001');
    });

    test('DESTRUCTION-06: Complete 24-Hour Real-World Timeline (08:00 to 17:00)', () async {
      const pCode = 'TILE-SUPER-60';
      const pName = 'سيراميك حمامات ومطابخ 60*60 بيج لامع';
      const pPrice = 38.0;

      // 08:00 - Opening Inventory: 500 m²
      await db.registerOrUpdateLocalItem(
        code: pCode,
        name: pName,
        category: 'سيراميك',
        unit: 'م²',
        initialQty: 500.0,
        unitPrice: pPrice,
      );

      // 09:00 - Goods Received from Jeddah: +150 m² -> 650
      final tId1 = await db.createNewCustomTransfer(
        transferNumber: 'DAY-TRF-0900',
        fromWarehouse: 'مستودع جدة',
        toWarehouse: 'مستودع بريدة',
        author: 'سعد القحطاني',
        notes: '',
        items: [{'item_code': pCode, 'item_name': pName, 'qty': 150.0, 'notes': ''}],
      );
      await db.confirmTransferAudit(tId1, 'audited_matched');

      // 10:00 - Transfer to Riyadh Warehouse: -100 m² -> 550
      await db.recordLocalStockAudit(pCode, pName, 650.0, 550.0, 'تحويل شحنة لفرع الرياض');

      // 11:00 - Customer Sale to Al-Fawzan: -60 m² (2280 SAR) -> 490
      await db.createSaleOrder(
        'sale-fawzan-01',
        'INV-FAW-1100',
        'مؤسسة الفوزان للتجارة',
        2280.0,
        [{'item_code': pCode, 'item_name': pName, 'qty': 60.0, 'unit_price': pPrice, 'total': 2280.0}],
      );

      // 12:00 - Customer Payment: 1280 SAR (Debt: 2280 -> 1000 SAR)
      CustomerModel.registerPaymentForCustomer('مؤسسة الفوزان للتجارة', 1280.0);
      final fawzan = CustomerModel.sampleCustomers.firstWhere((c) => c.name == 'مؤسسة الفوزان للتجارة');
      expect(fawzan.currentBalance, 1000.0);

      // 13:00 - Customer Return: +10 m² (380 SAR, Debt: 1000 -> 620 SAR) -> 500
      await db.createReturnInvoice(
        id: 'ret-fawzan-1300',
        returnNumber: 'RET-FAW-1300',
        returnType: 'sales',
        partyName: 'مؤسسة الفوزان للتجارة',
        date: '2026-08-29',
        refundMethod: 'خصم من الحساب',
        notes: '',
        totalAmount: 380.0,
        items: [{'item_code': pCode, 'item_name': pName, 'returned_qty': 10.0, 'unit': 'م²', 'base_qty': 10.0, 'unit_price': pPrice, 'reason': 'فائض فيلا'}],
      );
      CustomerModel.registerCustomerReturn('مؤسسة الفوزان للتجارة', 380.0);
      expect(fawzan.currentBalance, 620.0);

      // 14:00 - Supplier Return (Factory Defects): -15 m² -> 485
      await db.createReturnInvoice(
        id: 'ret-sup-1400',
        returnNumber: 'RET-SUP-1400',
        returnType: 'purchase',
        partyName: 'مصنع الخزف السعودي',
        date: '2026-08-29',
        refundMethod: 'استبدال',
        notes: 'بلاط مكسور أثناء التنزيل',
        totalAmount: 570.0,
        items: [{'item_code': pCode, 'item_name': pName, 'returned_qty': 15.0, 'unit': 'م²', 'base_qty': 15.0, 'unit_price': pPrice, 'reason': 'كسور وشروخ'}],
      );

      // 15:00 - Physical Inventory Count: Count finds 482 m² (Difference: -3 m² cutting samples) -> 482
      await db.recordLocalStockAudit(pCode, pName, 485.0, 482.0, 'جرد نهاية اليوم - عينات معروضة');

      // 17:00 - End of Day Audit & Mathematical Reconciliation
      // Expected = 500 + 150 - 100 - 60 + 10 - 15 - 3 = 482.0 m²
      final items = await db.getLocalItems();
      final tile = items.firstWhere((i) => i.code == pCode);
      expect(tile.currentStock, 482.0);
    });

    test('DESTRUCTION-07: Massive Stress Dataset (500+ Items, 10 Categories, 1000+ Records)', () async {
      final categories = [
        'سيراميك وبورسلان',
        'رخام وجرانيت',
        'إسمنت ومواد بناء',
        'دهانات وعوازل',
        'أدوات صحية وسباكة',
        'لواصق وترويبات',
        'أبواب وديكورات خشبية',
        'حديد ومعادن إنشائية',
        'إنارة وكهرباء',
        'أدوات ومعدات مستودع'
      ];

      // Bulk generate 500 products
      for (int i = 1; i <= 500; i++) {
        final cat = categories[i % categories.length];
        await db.registerOrUpdateLocalItem(
          code: 'SKU-MASS-${i.toString().padLeft(4, '0')}',
          name: 'صنف مستودع بناء $cat نخب $i',
          category: cat,
          unit: i % 2 == 0 ? 'كرتونة' : 'م²',
          initialQty: (i * 10).toDouble(),
          unitPrice: (20 + (i % 50)).toDouble(),
          location: 'ممر ${(i % 15) + 1} - بايكة $i',
        );
      }

      final allItems = await db.getLocalItems();
      expect(allItems.length, 500);

      // Verify fast querying & aggregation
      final ceramics = allItems.where((i) => i.category == 'سيراميك وبورسلان').toList();
      expect(ceramics.length, 50);

      final totalStock = allItems.fold<double>(0.0, (s, i) => s + i.currentStock);
      // sum(i * 10 for i in 1..500) = 10 * (500 * 501 / 2) = 10 * 125,250 = 1,252,500
      expect(totalStock, 1252500.0);
    });
  });
}
