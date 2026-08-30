import 'package:flutter_test/flutter_test.dart';
import 'package:benaa_flutter_mobile/data/models/item_model.dart';
import 'package:benaa_flutter_mobile/data/models/customer_model.dart';
import 'package:benaa_flutter_mobile/core/database/db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Benaa Stress, Chaos, Concurrency & Edge Cases QA Test Suite', () {
    late DBHelper db;

    setUp(() async {
      db = DBHelper();
      await db.clearAllDatabaseData();
      CustomerModel.clearAllCustomers();
    });

    test('Chaos Test 1: Rapid Duplicate Tap / Repeated Transfer Confirmation Protection', () async {
      // Create transfer of 100 bags of cement
      final tId = await db.createNewCustomTransfer(
        transferNumber: 'TRF-DUPLICATE-001',
        fromWarehouse: 'مستودع الرياض',
        toWarehouse: 'مستودع بريدة',
        author: 'فهد',
        notes: 'اختبار منع التكرار',
        items: [{'item_code': 'CEM-50', 'item_name': 'إسمنت بورتلاندي 50 كجم', 'qty': 100.0, 'notes': ''}],
      );

      // Initial Stock
      await db.registerOrUpdateLocalItem(
        code: 'CEM-50',
        name: 'إسمنت بورتلاندي 50 كجم',
        category: 'إسمنت',
        unit: 'كيس',
        initialQty: 500.0,
      );

      // Simulate rapid double click on "Confirm Audit" button
      await Future.wait([
        db.confirmTransferAudit(tId, 'audited_matched'),
        db.confirmTransferAudit(tId, 'audited_matched'),
      ]);

      // Stock must be updated properly and status must be audited
      final transfer = await db.getTransferById(tId);
      expect(transfer!.status, 'audited_matched');

      final items = await db.getLocalItems();
      final cement = items.firstWhere((i) => i.code == 'CEM-50');
      expect(cement.currentStock, 600.0); // 500 + 100
    });

    test('Chaos Test 2: Negative Stock Protection During Sales Issuance', () async {
      // Item has 50 in stock
      await db.registerOrUpdateLocalItem(
        code: 'PNT-GLOSS',
        name: 'دهان زيتي لامع 18 لتر',
        category: 'دهانات',
        unit: 'سطل',
        initialQty: 50.0,
      );

      // Attempt sale of 100 (exceeding stock)
      final saleQty = 100.0;
      await db.createSaleOrder(
        'sale-neg-01',
        'INV-NEG-01',
        'محل الأمل للدهانات',
        16500.0,
        [{'item_code': 'PNT-GLOSS', 'item_name': 'دهان زيتي لامع 18 لتر', 'qty': saleQty, 'unit_price': 165.0, 'total': 16500.0}],
      );

      // Check stock clamped at >= 0 (no negative corrupted stock)
      final items = await db.getLocalItems();
      final paint = items.firstWhere((i) => i.code == 'PNT-GLOSS');
      expect(paint.currentStock >= 0, true);
    });

    test('Chaos Test 3: Large Dataset Stress Test (50+ Products, Multiple Categories & Searches)', () async {
      final categories = ['سيراميك', 'رخام', 'إسمنت', 'دهانات', 'أدوات صحية', 'لواصق', 'عوازل', 'أبواب خشب'];

      for (int i = 1; i <= 60; i++) {
        final cat = categories[i % categories.length];
        await db.registerOrUpdateLocalItem(
          code: 'SKU-ITEM-${i.toString().padLeft(3, '0')}',
          name: 'منتج مستودع بناء $cat نمرة $i',
          category: cat,
          unit: i % 2 == 0 ? 'حبة' : 'م²',
          initialQty: (i * 10).toDouble(),
          unitPrice: (25 + i).toDouble(),
          location: 'ممر ${(i % 5) + 1} - رف $i',
        );
      }

      final items = await db.getLocalItems();
      expect(items.length, 60);

      // Search Tests
      // 1. Partial Search by Arabic Name
      final searchCeramic = items.where((i) => i.name.contains('سيراميك')).toList();
      expect(searchCeramic.isNotEmpty, true);

      // 2. Search by SKU
      final searchSku = items.where((i) => i.code == 'SKU-ITEM-042').toList();
      expect(searchSku.length, 1);
      expect(searchSku.first.currentStock, 420.0);

      // 3. Search Non-Existent Item
      final searchNotFound = items.where((i) => i.name.contains('منتج فضائي غير موجود')).toList();
      expect(searchNotFound.isEmpty, true);
    });

    test('Chaos Test 4: App Restart / Persistence Continuity Audit', () async {
      // 1. Setup Item & Transfer
      await db.registerOrUpdateLocalItem(
        code: 'ADH-SUPER-01',
        name: 'غراء إيبوكسي فائق القوة',
        category: 'لواصق',
        unit: 'علبة',
        initialQty: 150.0,
      );

      final tId = await db.createNewCustomTransfer(
        transferNumber: 'TRF-PERSIST-101',
        fromWarehouse: 'جدة',
        toWarehouse: 'بريدة',
        author: 'سالم',
        notes: 'ملاحظة بقاء البيانات',
        items: [{'item_code': 'ADH-SUPER-01', 'item_name': 'غراء إيبوكسي فائق القوة', 'qty': 50.0, 'notes': ''}],
      );

      await db.confirmTransferAudit(tId, 'audited_matched');

      // 2. Simulate complete app kill and cold restart by instantiating new helper access
      final reloadedDb = DBHelper();
      final reloadedItems = await reloadedDb.getLocalItems();
      final reloadedTransfers = await reloadedDb.getTransfers();

      // 3. Verify exact continuity
      final adhesive = reloadedItems.firstWhere((i) => i.code == 'ADH-SUPER-01');
      expect(adhesive.currentStock, 200.0); // 150 + 50
      expect(adhesive.name, 'غراء إيبوكسي فائق القوة');

      final transfer = reloadedTransfers.firstWhere((t) => t.id == tId);
      expect(transfer.status, 'audited_matched');
      expect(transfer.transferNumber, 'TRF-PERSIST-101');
    });

    test('Chaos Test 5: Customer Ledger Multi-Transaction Balance Audit', () async {
      const customer = 'شركة إعمار القصيم للتطوير العقاري';

      // 1. Sale 1: 10,000 SAR
      CustomerModel.registerSaleForCustomer(customer, 10000.0, phone: '0555123456');
      // 2. Sale 2: 5,500 SAR
      CustomerModel.registerSaleForCustomer(customer, 5500.0);
      // 3. Sale 3: 2,500 SAR
      CustomerModel.registerSaleForCustomer(customer, 2500.0);

      final c = CustomerModel.sampleCustomers.firstWhere((cust) => cust.name == customer);
      expect(c.currentBalance, 18000.0); // 10000 + 5500 + 2500
      expect(c.phone, '0555123456');
    });
  });
}
