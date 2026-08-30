import 'package:flutter_test/flutter_test.dart';
import 'package:benaa_flutter_mobile/data/models/item_model.dart';
import 'package:benaa_flutter_mobile/data/models/product_unit_model.dart';
import 'package:benaa_flutter_mobile/data/models/transfer_model.dart';
import 'package:benaa_flutter_mobile/data/models/customer_model.dart';
import 'package:benaa_flutter_mobile/data/models/return_invoice_model.dart';
import 'package:benaa_flutter_mobile/core/database/db_helper.dart';
import 'package:benaa_flutter_mobile/core/services/unit_conversion_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Benaa Real-World Warehouse QA & E2E Test Suite', () {
    late DBHelper db;

    // Realistic Products Dataset
    late ItemModel porcelainTile;
    late ItemModel whiteCement;
    late ItemModel wallPaint;
    late ItemModel tileAdhesive;
    late ItemModel italianMarble;
    late ItemModel sanitaryMixer;

    setUp(() async {
      db = DBHelper();
      await db.clearAllDatabaseData();
      CustomerModel.clearAllCustomers();

      // 1. Porcelain Tile 60x120 Beige (Base: m², Box: 1.44 m², Pallet: 43.20 m²)
      porcelainTile = ItemModel(
        code: 'CER-60120-BEI',
        name: 'بورسلان بيج 60*120 نخب أول',
        category: 'سيراميك وبورسلان',
        legacyUnit: 'م²',
        currentStock: 500.0,
        unitPrice: 45.0,
        location: 'ممر A - رف 12',
        units: [
          ProductUnitModel(id: 'u_p1', productCode: 'CER-60120-BEI', unitName: 'م²', unitType: UnitType.area, conversionFactor: 1.0, isBase: true, salePrice: 45.0),
          ProductUnitModel(id: 'u_p2', productCode: 'CER-60120-BEI', unitName: 'كرتونة', unitType: UnitType.packaging, conversionFactor: 1.44, isBase: false, salePrice: 64.80),
          ProductUnitModel(id: 'u_p3', productCode: 'CER-60120-BEI', unitName: 'طبلية', unitType: UnitType.packaging, conversionFactor: 43.20, isBase: false, salePrice: 1944.0),
        ],
      );

      // 2. White Cement 50kg (Base: Bag, Pallet: 40 Bags, Ton: 20 Bags)
      whiteCement = ItemModel(
        code: 'CEM-W50',
        name: 'إسمنت أبيض عالي الجودة 50 كجم',
        category: 'إسمنت ومواد بناء',
        legacyUnit: 'كيس',
        currentStock: 1000.0,
        unitPrice: 28.0,
        location: 'مستودع الساحات - بايكة 3',
        units: [
          ProductUnitModel(id: 'u_c1', productCode: 'CEM-W50', unitName: 'كيس', unitType: UnitType.count, conversionFactor: 1.0, isBase: true, salePrice: 28.0),
          ProductUnitModel(id: 'u_c2', productCode: 'CEM-W50', unitName: 'طبلية', unitType: UnitType.packaging, conversionFactor: 40.0, isBase: false, salePrice: 1120.0),
          ProductUnitModel(id: 'u_c3', productCode: 'CEM-W50', unitName: 'طن', unitType: UnitType.weight, conversionFactor: 20.0, isBase: false, salePrice: 560.0),
        ],
      );

      // 3. Interior Wall Paint 18L White (Base: Can)
      wallPaint = ItemModel(
        code: 'PNT-18-WHT',
        name: 'دهان داخلي مطفي أبيض 18 لتر',
        category: 'دهانات وتشطيب',
        legacyUnit: 'سطل',
        currentStock: 250.0,
        unitPrice: 165.0,
        location: 'ممر B - رف 4',
      );

      // 4. Tile Adhesive 20kg (Base: Bag)
      tileAdhesive = ItemModel(
        code: 'ADH-20',
        name: 'غراء سيراميك فائق الالتصاق 20 كجم',
        category: 'لواصق وغراء',
        legacyUnit: 'كيس',
        currentStock: 400.0,
        unitPrice: 22.0,
        location: 'ممر A - رف 2',
      );

      // 5. Italian Carrara Marble Slab (Base: m²)
      italianMarble = ItemModel(
        code: 'MAR-CAR-01',
        name: 'رخام كرارة إيطالي نخب أول',
        category: 'رخام وجرانيت',
        legacyUnit: 'م²',
        currentStock: 120.0,
        unitPrice: 320.0,
        location: 'معرض الرخام - جناح 1',
      );

      // 6. Sanitary Mixer Chrome (Base: Piece, Box: 12 Pieces)
      sanitaryMixer = ItemModel(
        code: 'SAN-MIX-CHR',
        name: 'خلاط مغسلة ألماني كروم فاخر',
        category: 'أدوات صحية',
        legacyUnit: 'حبة',
        currentStock: 80.0,
        unitPrice: 185.0,
        location: 'ممر C - كابينة 8',
      );

      // Initialize dataset in database
      await db.registerOrUpdateLocalItem(
        code: porcelainTile.code,
        name: porcelainTile.name,
        category: porcelainTile.category,
        unit: porcelainTile.unit,
        initialQty: porcelainTile.currentStock,
        unitPrice: porcelainTile.unitPrice,
        location: porcelainTile.location,
      );
      await db.registerOrUpdateLocalItem(
        code: whiteCement.code,
        name: whiteCement.name,
        category: whiteCement.category,
        unit: whiteCement.unit,
        initialQty: whiteCement.currentStock,
        unitPrice: whiteCement.unitPrice,
        location: whiteCement.location,
      );
      await db.registerOrUpdateLocalItem(
        code: wallPaint.code,
        name: wallPaint.name,
        category: wallPaint.category,
        unit: wallPaint.unit,
        initialQty: wallPaint.currentStock,
        unitPrice: wallPaint.unitPrice,
        location: wallPaint.location,
      );
      await db.registerOrUpdateLocalItem(
        code: tileAdhesive.code,
        name: tileAdhesive.name,
        category: tileAdhesive.category,
        unit: tileAdhesive.unit,
        initialQty: tileAdhesive.currentStock,
        unitPrice: tileAdhesive.unitPrice,
        location: tileAdhesive.location,
      );
      await db.registerOrUpdateLocalItem(
        code: italianMarble.code,
        name: italianMarble.name,
        category: italianMarble.category,
        unit: italianMarble.unit,
        initialQty: italianMarble.currentStock,
        unitPrice: italianMarble.unitPrice,
        location: italianMarble.location,
      );
      await db.registerOrUpdateLocalItem(
        code: sanitaryMixer.code,
        name: sanitaryMixer.name,
        category: sanitaryMixer.category,
        unit: sanitaryMixer.unit,
        initialQty: sanitaryMixer.currentStock,
        unitPrice: sanitaryMixer.unitPrice,
        location: sanitaryMixer.location,
      );
    });

    test('QA Scenario 1: Initial Inventory Verification & Exact Balances', () async {
      final items = await db.getLocalItems();
      expect(items.length, 6);

      final pTile = items.firstWhere((i) => i.code == 'CER-60120-BEI');
      expect(pTile.currentStock, 500.0);
      expect(pTile.unitPrice, 45.0);
      expect(pTile.name, 'بورسلان بيج 60*120 نخب أول');

      final cement = items.firstWhere((i) => i.code == 'CEM-W50');
      expect(cement.currentStock, 1000.0);

      final paint = items.firstWhere((i) => i.code == 'PNT-18-WHT');
      expect(paint.currentStock, 250.0);

      final adhesive = items.firstWhere((i) => i.code == 'ADH-20');
      expect(adhesive.currentStock, 400.0);

      final totalValuation = items.fold<double>(0.0, (sum, i) => sum + (i.currentStock * i.unitPrice));
      // 500*45 + 1000*28 + 250*165 + 400*22 + 120*320 + 80*185
      // 22500 + 28000 + 41250 + 8800 + 38400 + 14800 = 153,750 SAR
      expect(totalValuation, 153750.0);
    });

    test('QA Scenario 2: Receiving Shipment from Main Warehouse (Jeddah -> Buraidah)', () async {
      // Incoming Transfer from Jeddah to Buraidah (100 m² Porcelain, 200 bags Cement)
      final transferId = await db.createNewCustomTransfer(
        transferNumber: 'TRF-JED-BUR-881',
        fromWarehouse: 'مستودع جدة الرئيسي',
        toWarehouse: 'مستودع بريدة (القصيم)',
        author: 'أمين المستودع - خالد العتيبي',
        notes: 'شحنة توريد مواد بناء دورية للمنطقة الوسطى',
        items: [
          {'item_code': 'CER-60120-BEI', 'item_name': 'بورسلان بيج 60*120 نخب أول', 'qty': 100.0, 'notes': 'سليمة'},
          {'item_code': 'CEM-W50', 'item_name': 'إسمنت أبيض عالي الجودة 50 كجم', 'qty': 200.0, 'notes': 'سليمة'},
        ],
      );

      expect(transferId, isNotEmpty);

      // Verify status is pending before audit confirmation
      var transfer = await db.getTransferById(transferId);
      expect(transfer, isNotNull);
      expect(transfer!.status, 'pending_audit');

      // Verify stock does NOT change BEFORE audit confirmation
      var itemsBefore = await db.getLocalItems();
      var pTileBefore = itemsBefore.firstWhere((i) => i.code == 'CER-60120-BEI');
      expect(pTileBefore.currentStock, 500.0);

      // Confirm transfer receipt
      await db.confirmTransferAudit(transferId, 'audited_matched');

      // Verify stock updated accurately
      var itemsAfter = await db.getLocalItems();
      var pTileAfter = itemsAfter.firstWhere((i) => i.code == 'CER-60120-BEI');
      var cementAfter = itemsAfter.firstWhere((i) => i.code == 'CEM-W50');

      expect(pTileAfter.currentStock, 600.0); // 500 + 100
      expect(cementAfter.currentStock, 1200.0); // 1000 + 200
    });

    test('QA Scenario 3: Receiving Discrepancy & Damaged Shipment Handling with Photo Attachment', () async {
      // Transfer of 50 Cans of Paint with damaged deficit of 5 cans
      final transferId = await db.createNewCustomTransfer(
        transferNumber: 'TRF-JED-BUR-882',
        fromWarehouse: 'مستودع جدة الرئيسي',
        toWarehouse: 'مستودع بريدة (القصيم)',
        author: 'سائق الشاحنة - أبو فهد',
        notes: 'شحنة دهانات',
        items: [
          {'item_code': 'PNT-18-WHT', 'item_name': 'دهان داخلي مطفي أبيض 18 لتر', 'qty': 50.0, 'notes': ''},
        ],
      );

      final transfer = await db.getTransferById(transferId);
      final itemToAudit = transfer!.items.first;

      // Warehouse manager counts 45 good cans, 5 damaged/leaking cans with photo evidence
      await db.updateTransferItemQty(
        itemToAudit.id!,
        45.0, // actual received
        'تم استلام 45 سطل سليم ووجود 5 سطول تالفة ومنسكبة أثناء النقل',
        imagePath: 'DAMAGED-PNT-18-WHT-photo-evidence.jpg',
      );

      // Confirm with discrepancy status
      await db.confirmTransferAudit(transferId, 'audited_discrepancy');

      final auditedTransfer = await db.getTransferById(transferId);
      expect(auditedTransfer!.status, 'audited_discrepancy');
      expect(auditedTransfer.items.first.actualQty, 45.0);
      expect(auditedTransfer.items.first.hasDiscrepancy, true);
      expect(auditedTransfer.items.first.discrepancy, -5.0);
      expect(auditedTransfer.items.first.imagePath, 'DAMAGED-PNT-18-WHT-photo-evidence.jpg');

      // Verify local inventory only added the actual intact stock (45 cans)
      final items = await db.getLocalItems();
      final paint = items.firstWhere((i) => i.code == 'PNT-18-WHT');
      expect(paint.currentStock, 295.0); // 250 + 45
    });

    test('QA Scenario 4: Sales Issuance, Stock Deduction & Customer Balance Ledger', () async {
      // Sale to Al-Omran Contracting Est.
      final saleId = 'sale-omran-001';
      final invoiceNum = 'INV-BUR-9001';
      final customerName = 'مؤسسة العمران للمقاولات العامة';

      final cartItems = [
        {
          'item_code': 'CER-60120-BEI',
          'item_name': 'بورسلان بيج 60*120 نخب أول',
          'qty': 50.0,
          'unit': 'م²',
          'unit_price': 45.0,
          'total': 2250.0,
        },
        {
          'item_code': 'CEM-W50',
          'item_name': 'إسمنت أبيض عالي الجودة 50 كجم',
          'qty': 100.0,
          'unit': 'كيس',
          'unit_price': 28.0,
          'total': 2800.0,
        },
      ];
      final totalAmount = 5050.0;

      await db.createSaleOrder(saleId, invoiceNum, customerName, totalAmount, cartItems);

      // Verify stock deducted
      final items = await db.getLocalItems();
      final pTile = items.firstWhere((i) => i.code == 'CER-60120-BEI');
      final cement = items.firstWhere((i) => i.code == 'CEM-W50');

      expect(pTile.currentStock, 450.0); // 500 - 50
      expect(cement.currentStock, 900.0); // 1000 - 100

      // Verify customer ledger debt recorded
      expect(CustomerModel.sampleCustomers.length, 1);
      final customer = CustomerModel.sampleCustomers.first;
      expect(customer.name, customerName);
      expect(customer.currentBalance, 5050.0);

      // Verify customer sales history
      final customerSales = await db.getSalesForCustomer(customerName);
      expect(customerSales.length, 1);
      expect(customerSales.first['invoice_number'], invoiceNum);
    });

    test('QA Scenario 5: Customer Sales Return Restoring Stock and Adjusting Ledger', () async {
      // Customer returns 10 m² of Porcelain from previous sale
      final returnId = 'ret-omran-001';
      final returnNum = 'RET-BUR-301';

      await db.createReturnInvoice(
        id: returnId,
        returnNumber: returnNum,
        returnType: 'sales',
        partyName: 'مؤسسة العمران للمقاولات العامة',
        date: DateTime.now().toIso8601String().split('T').first,
        refundMethod: 'خصم من رصيد الحساب',
        notes: 'مرتجع فائض من مشروع فيلا حي الرمال',
        totalAmount: 450.0,
        items: [
          {
            'item_code': 'CER-60120-BEI',
            'item_name': 'بورسلان بيج 60*120 نخب أول',
            'returned_qty': 10.0,
            'unit': 'م²',
            'base_qty': 10.0,
            'unit_price': 45.0,
            'reason': 'زيادة عن حاجة المشروع',
          },
        ],
      );

      // Verify stock increased by returned quantity
      final items = await db.getLocalItems();
      final pTile = items.firstWhere((i) => i.code == 'CER-60120-BEI');
      expect(pTile.currentStock, 510.0); // 500 + 10 returned

      // Verify return invoice stored
      final returns = await db.getReturnInvoices();
      expect(returns.length, 1);
      expect(returns.first['return_number'], returnNum);
    });

    test('QA Scenario 6: Supplier Purchase Return Deducting Stock', () async {
      // Returning 20 defective adhesive bags to supplier (Al-Majd)
      final returnId = 'ret-sup-001';
      final returnNum = 'RET-SUP-101';

      await db.createReturnInvoice(
        id: returnId,
        returnNumber: returnNum,
        returnType: 'purchase',
        partyName: 'شركة المجد لمواد البناء والديكور',
        date: DateTime.now().toIso8601String().split('T').first,
        refundMethod: 'مطالبة استرداد من المورد',
        notes: 'أكياس متكتلة بسبب رطوبة المصنع',
        totalAmount: 440.0,
        items: [
          {
            'item_code': 'ADH-20',
            'item_name': 'غراء سيراميك فائق الالتصاق 20 كجم',
            'returned_qty': 20.0,
            'unit': 'كيس',
            'base_qty': 20.0,
            'unit_price': 22.0,
            'reason': 'عيوب تصنيع وتكتل',
          },
        ],
      );

      // Verify stock decreased by supplier return quantity
      final items = await db.getLocalItems();
      final adhesive = items.firstWhere((i) => i.code == 'ADH-20');
      expect(adhesive.currentStock, 380.0); // 400 - 20
    });

    test('QA Scenario 7: Physical Stocktake & Direct Stock Adjustment', () async {
      // System stock for Italian Marble is 120 m²
      // Physical count finds 118 m² (Difference of -2 m² due to cutting samples)
      await db.recordLocalStockAudit(
        'MAR-CAR-01',
        'رخام كرارة إيطالي نخب أول',
        120.0,
        118.0,
        'جرد دوري شهري - عجز 2 متر مستخدمة في قص عينات للزبائن',
      );

      final items = await db.getLocalItems();
      final marble = items.firstWhere((i) => i.code == 'MAR-CAR-01');
      expect(marble.currentStock, 118.0);
    });

    test('QA Scenario 8: Multilevel Unit Conversions & Packaging Calculator Audit', () async {
      // 5 Pallets of Porcelain (1 Pallet = 43.20 m²) -> 216.0 m²
      final baseQty1 = UnitConversionEngine.convertToBaseUnit(
        item: porcelainTile,
        unitName: 'طبلية',
        quantity: 5.0,
      );
      expect(baseQty1, 216.0);

      // 10 Cartons of Porcelain (1 Carton = 1.44 m²) -> 14.4 m²
      final baseQty2 = UnitConversionEngine.convertToBaseUnit(
        item: porcelainTile,
        unitName: 'كرتونة',
        quantity: 10.0,
      );
      expect(baseQty2, 14.4);

      // Hybrid quantity: 2 Pallets + 5 Cartons + 3 m²
      final hybridInputs = [
        UnitQuantityInput(unitName: 'طبلية', quantity: 2.0), // 2 * 43.20 = 86.40
        UnitQuantityInput(unitName: 'كرتونة', quantity: 5.0), // 5 * 1.44 = 7.20
        UnitQuantityInput(unitName: 'م²', quantity: 3.0), // 3.0
      ];
      final totalHybrid = UnitConversionEngine.calculateHybridQuantity(
        item: porcelainTile,
        inputs: hybridInputs,
      );
      expect(totalHybrid, 96.60); // 86.40 + 7.20 + 3.00
    });

    test('QA Scenario 9: Full Mathematical Lifecycle Consistency Audit', () async {
      // Let's trace Sanitary Mixers:
      // Opening: 80
      // Receive: +40
      // Sale: -30
      // Customer Return: +5
      // Supplier Return: -2
      // Physical adjustment to actual: 93

      // 1. Receive 40
      final tId = await db.createNewCustomTransfer(
        transferNumber: 'TRF-MIX-01',
        fromWarehouse: 'مستودع الرياض',
        toWarehouse: 'مستودع بريدة',
        author: 'محمد',
        notes: 'توريد خلاطات',
        items: [{'item_code': 'SAN-MIX-CHR', 'item_name': 'خلاط مغسلة ألماني كروم فاخر', 'qty': 40.0, 'notes': ''}],
      );
      await db.confirmTransferAudit(tId, 'audited_matched');

      // 2. Sale 30
      await db.createSaleOrder(
        'sale-mix-01',
        'INV-MIX-01',
        'مؤسسة النور للسباكة',
        5550.0,
        [{'item_code': 'SAN-MIX-CHR', 'item_name': 'خلاط مغسلة ألماني كروم فاخر', 'qty': 30.0, 'unit_price': 185.0, 'total': 5550.0}],
      );

      // 3. Customer Return 5
      await db.createReturnInvoice(
        id: 'ret-mix-01',
        returnNumber: 'RET-MIX-01',
        returnType: 'sales',
        partyName: 'مؤسسة النور للسباكة',
        date: '2026-08-29',
        refundMethod: 'خصم',
        notes: 'مرتجع خلاطات',
        totalAmount: 925.0,
        items: [{'item_code': 'SAN-MIX-CHR', 'item_name': 'خلاط مغسلة ألماني كروم فاخر', 'returned_qty': 5.0, 'unit': 'حبة', 'base_qty': 5.0, 'unit_price': 185.0, 'reason': 'فائض'}],
      );

      // 4. Supplier Return 2
      await db.createReturnInvoice(
        id: 'ret-mix-sup-01',
        returnNumber: 'RET-MIX-SUP-01',
        returnType: 'purchase',
        partyName: 'وكالة الخلاطات الألمانية',
        date: '2026-08-29',
        refundMethod: 'استبدال',
        notes: 'خلاطات بها خدوش',
        totalAmount: 370.0,
        items: [{'item_code': 'SAN-MIX-CHR', 'item_name': 'خلاط مغسلة ألماني كروم فاخر', 'returned_qty': 2.0, 'unit': 'حبة', 'base_qty': 2.0, 'unit_price': 185.0, 'reason': 'خدش خارجي'}],
      );

      // Expected mathematical balance: 80 + 40 - 30 + 5 - 2 = 93
      final items = await db.getLocalItems();
      final mixer = items.firstWhere((i) => i.code == 'SAN-MIX-CHR');
      expect(mixer.currentStock, 93.0);
    });
  });
}
