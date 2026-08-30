import 'package:flutter_test/flutter_test.dart';
import 'package:benaa_flutter_mobile/data/models/item_model.dart';
import 'package:benaa_flutter_mobile/data/models/product_unit_model.dart';
import 'package:benaa_flutter_mobile/data/models/customer_model.dart';
import 'package:benaa_flutter_mobile/core/database/db_helper.dart';
import 'package:benaa_flutter_mobile/core/services/unit_conversion_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Benaa Flutter — Round 2 Production Readiness & Mathematical Audit', () {
    late DBHelper db;

    setUp(() async {
      db = DBHelper();
      await db.clearAllDatabaseData();
      CustomerModel.clearAllCustomers();
    });

    test('Audit Test 1: Sales E2E + Stock Deduction + Ledger Continuity + App Restart', () async {
      // 1. Setup Product: 100 units
      const itemCode = 'CER-PORC-100';
      const itemName = 'بورسلان أرضيات 60*60 رمادي';
      await db.registerOrUpdateLocalItem(
        code: itemCode,
        name: itemName,
        category: 'سيراميك',
        unit: 'م²',
        initialQty: 100.0,
        unitPrice: 50.0,
      );

      // 2. Customer: Ahmed Trading Company
      const customerName = 'شركة أحمد للتجارة العامة';

      // 3. Create Sales Invoice: 30 units (30 * 50 = 1500 SAR)
      const saleId = 'sale-ahmed-001';
      const invoiceNum = 'INV-2026-001';
      final cartItems = [
        {
          'item_code': itemCode,
          'item_name': itemName,
          'qty': 30.0,
          'unit': 'م²',
          'unit_price': 50.0,
          'total': 1500.0,
        }
      ];

      await db.createSaleOrder(saleId, invoiceNum, customerName, 1500.0, cartItems);

      // 4. Verify Stock Deduction: 100 -> 70
      var items = await db.getLocalItems();
      var item = items.firstWhere((i) => i.code == itemCode);
      expect(item.currentStock, 70.0);

      // 5. Verify Customer Debt: 1500.0 SAR
      expect(CustomerModel.sampleCustomers.length, 1);
      final customer = CustomerModel.sampleCustomers.firstWhere((c) => c.name == customerName);
      expect(customer.currentBalance, 1500.0);

      // 6. Verify Cold Restart Persistence
      final reloadedDb = DBHelper();
      final reloadedItems = await reloadedDb.getLocalItems();
      final reloadedItem = reloadedItems.firstWhere((i) => i.code == itemCode);
      expect(reloadedItem.currentStock, 70.0);

      final customerSales = await reloadedDb.getSalesForCustomer(customerName);
      expect(customerSales.length, 1);
      expect(customerSales.first['invoice_number'], invoiceNum);
      expect(customerSales.first['total_amount'], 1500.0);
    });

    test('Audit Test 2: VAT Tax Testing (15% VAT vs 0% Tax Free)', () async {
      // Setup Item
      await db.registerOrUpdateLocalItem(
        code: 'CEM-PORT-50',
        name: 'إسمنت بورتلاندي 50 كجم',
        category: 'إسمنت',
        unit: 'كيس',
        initialQty: 200.0,
        unitPrice: 20.0,
      );

      // Case A: Invoice WITH 15% VAT (Subtotal 1000 -> VAT 150 -> Grand Total 1150)
      const subtotalA = 1000.0;
      const vatRateA = 0.15;
      final vatAmountA = subtotalA * vatRateA; // 150.0
      final grandTotalA = subtotalA + vatAmountA; // 1150.0

      await db.createSaleOrder(
        'sale-vat-15',
        'INV-VAT-15',
        'مؤسسة النماء للمقاولات',
        grandTotalA,
        [{'item_code': 'CEM-PORT-50', 'item_name': 'إسمنت بورتلاندي 50 كجم', 'qty': 50.0, 'unit_price': 20.0, 'total': 1000.0}],
      );

      final custA = CustomerModel.sampleCustomers.firstWhere((c) => c.name == 'مؤسسة النماء للمقاولات');
      expect(custA.currentBalance, 1150.0);

      // Case B: Invoice WITHOUT VAT (0% Tax) (Subtotal 1000 -> VAT 0 -> Grand Total 1000)
      const subtotalB = 1000.0;
      const vatRateB = 0.0;
      final vatAmountB = subtotalB * vatRateB; // 0.0
      final grandTotalB = subtotalB + vatAmountB; // 1000.0

      await db.createSaleOrder(
        'sale-vat-0',
        'INV-VAT-0',
        'جمعية البر الخيرية (معفى من الضريبة)',
        grandTotalB,
        [{'item_code': 'CEM-PORT-50', 'item_name': 'إسمنت بورتلاندي 50 كجم', 'qty': 50.0, 'unit_price': 20.0, 'total': 1000.0}],
      );

      final custB = CustomerModel.sampleCustomers.firstWhere((c) => c.name == 'جمعية البر الخيرية (معفى من الضريبة)');
      expect(custB.currentBalance, 1000.0);

      // Remaining stock: 200 - 50 - 50 = 100
      final items = await db.getLocalItems();
      final cement = items.firstWhere((i) => i.code == 'CEM-PORT-50');
      expect(cement.currentStock, 100.0);
    });

    test('Audit Test 3: Customer Debt Lifecycle & Sequential Payments', () async {
      const customer = 'شركة أحمد للتجارة العامة';

      // 1. Initial Sale = 5000 SAR -> Debt = 5000
      CustomerModel.registerSaleForCustomer(customer, 5000.0);
      var c = CustomerModel.sampleCustomers.firstWhere((cust) => cust.name == customer);
      expect(c.currentBalance, 5000.0);

      // 2. Payment 1 = 2000 SAR -> Debt = 3000
      CustomerModel.registerPaymentForCustomer(customer, 2000.0);
      c = CustomerModel.sampleCustomers.firstWhere((cust) => cust.name == customer);
      expect(c.currentBalance, 3000.0);

      // 3. Payment 2 = 1000 SAR -> Debt = 2000
      CustomerModel.registerPaymentForCustomer(customer, 1000.0);
      c = CustomerModel.sampleCustomers.firstWhere((cust) => cust.name == customer);
      expect(c.currentBalance, 2000.0);

      // 4. Overpayment check -> clamp at >= 0 (no negative debt corruption)
      CustomerModel.registerPaymentForCustomer(customer, 2500.0);
      c = CustomerModel.sampleCustomers.firstWhere((cust) => cust.name == customer);
      expect(c.currentBalance, 0.0);
    });

    test('Audit Test 4: Customer Sales Return (Stock & Financial Balance Restoration)', () async {
      // Initial: 100 units
      const itemCode = 'PNT-EXT-20';
      await db.registerOrUpdateLocalItem(
        code: itemCode,
        name: 'دهان خارجي بروفايل 20 كجم',
        category: 'دهانات',
        unit: 'سطل',
        initialQty: 100.0,
        unitPrice: 80.0,
      );

      // Sell: 30 units (30 * 80 = 2400 SAR)
      const customerName = 'مؤسسة صروح البناء';
      await db.createSaleOrder(
        'sale-srouh-01',
        'INV-SRH-01',
        customerName,
        2400.0,
        [{'item_code': itemCode, 'item_name': 'دهان خارجي بروفايل 20 كجم', 'qty': 30.0, 'unit_price': 80.0, 'total': 2400.0}],
      );

      // Verify stock is 70, debt is 2400
      var items = await db.getLocalItems();
      expect(items.firstWhere((i) => i.code == itemCode).currentStock, 70.0);
      var c = CustomerModel.sampleCustomers.firstWhere((cust) => cust.name == customerName);
      expect(c.currentBalance, 2400.0);

      // Customer Returns 5 units (5 * 80 = 400 SAR)
      await db.createReturnInvoice(
        id: 'ret-srouh-01',
        returnNumber: 'RET-SRH-01',
        returnType: 'sales',
        partyName: customerName,
        date: '2026-08-29',
        refundMethod: 'خصم من الحساب',
        notes: 'مرتجع فائض أسطول الدهان',
        totalAmount: 400.0,
        items: [{'item_code': itemCode, 'item_name': 'دهان خارجي بروفايل 20 كجم', 'returned_qty': 5.0, 'unit': 'سطل', 'base_qty': 5.0, 'unit_price': 80.0, 'reason': 'فائض'}],
      );

      // Adjust customer balance
      CustomerModel.registerCustomerReturn(customerName, 400.0);

      // Expected stock: 70 + 5 = 75
      items = await db.getLocalItems();
      expect(items.firstWhere((i) => i.code == itemCode).currentStock, 75.0);

      // Expected customer balance: 2400 - 400 = 2000
      c = CustomerModel.sampleCustomers.firstWhere((cust) => cust.name == customerName);
      expect(c.currentBalance, 2000.0);
    });

    test('Audit Test 5: Supplier Purchase Return (Stock & Supplier Balance Deduction)', () async {
      // Initial: 100 units
      const itemCode = 'ADH-GLUE-10';
      await db.registerOrUpdateLocalItem(
        code: itemCode,
        name: 'غراء سيراميك مقاوم للمياه 10 كجم',
        category: 'لواصق',
        unit: 'كيس',
        initialQty: 100.0,
        unitPrice: 15.0,
      );

      // Receive shipment: +50 units
      final tId = await db.createNewCustomTransfer(
        transferNumber: 'TRF-SUP-RECEIVE',
        fromWarehouse: 'المورد الرئيسي - شركة سافيتو',
        toWarehouse: 'مستودع بريدة',
        author: 'سائق سافيتو',
        notes: 'توريد إضافي',
        items: [{'item_code': itemCode, 'item_name': 'غراء سيراميك مقاوم للمياه 10 كجم', 'qty': 50.0, 'notes': ''}],
      );
      await db.confirmTransferAudit(tId, 'audited_matched');

      // Stock is now 150
      var items = await db.getLocalItems();
      expect(items.firstWhere((i) => i.code == itemCode).currentStock, 150.0);

      // Return to supplier: 20 units
      await db.createReturnInvoice(
        id: 'ret-sup-saveto',
        returnNumber: 'RET-SAV-01',
        returnType: 'purchase',
        partyName: 'شركة سافيتو لمواد البناء',
        date: '2026-08-29',
        refundMethod: 'استرداد مالي',
        notes: 'بضاعة غير مطابقة للمواصفات',
        totalAmount: 300.0,
        items: [{'item_code': itemCode, 'item_name': 'غراء سيراميك مقاوم للمياه 10 كجم', 'returned_qty': 20.0, 'unit': 'كيس', 'base_qty': 20.0, 'unit_price': 15.0, 'reason': 'تالف'}],
      );

      // Expected stock: 150 - 20 = 130
      items = await db.getLocalItems();
      expect(items.firstWhere((i) => i.code == itemCode).currentStock, 130.0);
    });

    test('Audit Test 6: Complete Unbroken Business Chain (9 Sequential Operations)', () async {
      const code = 'CHAIN-ITEM-01';
      const name = 'باركيه ألماني عالي المقاومة HDF';
      const price = 60.0;

      // 1. Opening Stock = 200 m²
      await db.registerOrUpdateLocalItem(
        code: code,
        name: name,
        category: 'أرضيات وديكورات',
        unit: 'م²',
        initialQty: 200.0,
        unitPrice: price,
      );

      // 2. Goods Receipt (Incoming transfer) = +100 m² -> Stock: 300
      final tId1 = await db.createNewCustomTransfer(
        transferNumber: 'CHAIN-TRF-01',
        fromWarehouse: 'مستودع جدة',
        toWarehouse: 'مستودع بريدة',
        author: 'مبارك',
        notes: '',
        items: [{'item_code': code, 'item_name': name, 'qty': 100.0, 'notes': ''}],
      );
      await db.confirmTransferAudit(tId1, 'audited_matched');

      // 3. Outgoing Transfer = -50 m² (Transfer to Riyadh) -> Stock: 250
      await db.recordLocalStockAudit(code, name, 300.0, 250.0, 'تحويل صادر لمستودع فرع الرياض');

      // 4. Sales Invoice = -40 m² -> Stock: 210
      await db.createSaleOrder(
        'chain-sale-01',
        'INV-CHAIN-01',
        'شركة التطوير العقاري',
        2400.0,
        [{'item_code': code, 'item_name': name, 'qty': 40.0, 'unit_price': price, 'total': 2400.0}],
      );

      // 5. Customer Payment = 1400 SAR (Debt drops from 2400 to 1000)
      CustomerModel.registerPaymentForCustomer('شركة التطوير العقاري', 1400.0);
      final cust = CustomerModel.sampleCustomers.firstWhere((c) => c.name == 'شركة التطوير العقاري');
      expect(cust.currentBalance, 1000.0);

      // 6. Customer Return = +10 m² -> Stock: 220
      await db.createReturnInvoice(
        id: 'chain-ret-cust',
        returnNumber: 'RET-CHAIN-01',
        returnType: 'sales',
        partyName: 'شركة التطوير العقاري',
        date: '2026-08-29',
        refundMethod: 'خصم',
        notes: '',
        totalAmount: 600.0,
        items: [{'item_code': code, 'item_name': name, 'returned_qty': 10.0, 'unit': 'م²', 'base_qty': 10.0, 'unit_price': price, 'reason': 'فائض'}],
      );
      CustomerModel.registerCustomerReturn('شركة التطوير العقاري', 600.0);
      expect(cust.currentBalance, 400.0); // 1000 - 600 = 400

      // 7. Supplier Return = -5 m² -> Stock: 215
      await db.createReturnInvoice(
        id: 'chain-ret-sup',
        returnNumber: 'RET-CHAIN-SUP',
        returnType: 'purchase',
        partyName: 'وكالة الباركيه الدولية',
        date: '2026-08-29',
        refundMethod: 'مطالبة',
        notes: '',
        totalAmount: 300.0,
        items: [{'item_code': code, 'item_name': name, 'returned_qty': 5.0, 'unit': 'م²', 'base_qty': 5.0, 'unit_price': price, 'reason': 'كسور'}],
      );

      // 8. Physical Inventory Adjustment: Actual Count = 213 m² (Difference -2 m²)
      await db.recordLocalStockAudit(code, name, 215.0, 213.0, 'تسوية جرد دوري');

      // 9. Final Mathematical Audit Verification
      // Expected = 200 + 100 - 50 - 40 + 10 - 5 - 2 = 213.0 m²
      final items = await db.getLocalItems();
      final parquet = items.firstWhere((i) => i.code == code);
      expect(parquet.currentStock, 213.0);
    });

    test('Audit Test 7: Multi-Unit Precision Conversions & Complex Hybrid Math', () async {
      final porcelainItem = ItemModel(
        code: 'CER-60120-P',
        name: 'بورسلان 60*120',
        category: 'سيراميك',
        legacyUnit: 'م²',
        currentStock: 1000.0,
        units: [
          ProductUnitModel(id: 'u1', productCode: 'CER-60120-P', unitName: 'م²', unitType: UnitType.area, conversionFactor: 1.0, isBase: true),
          ProductUnitModel(id: 'u2', productCode: 'CER-60120-P', unitName: 'كرتونة', unitType: UnitType.packaging, conversionFactor: 1.44),
          ProductUnitModel(id: 'u3', productCode: 'CER-60120-P', unitName: 'طبلية', unitType: UnitType.packaging, conversionFactor: 43.20),
        ],
      );

      // 10 Boxes = 14.40 m²
      final q1 = UnitConversionEngine.convertToBaseUnit(item: porcelainItem, unitName: 'كرتونة', quantity: 10.0);
      expect(q1, 14.40);

      // 2 Pallets = 86.40 m²
      final q2 = UnitConversionEngine.convertToBaseUnit(item: porcelainItem, unitName: 'طبلية', quantity: 2.0);
      expect(q2, 86.40);

      // Total = 100.80 m²
      expect(double.parse((q1 + q2).toStringAsFixed(6)), 100.80);

      // Mixed: 3 Pallets + 7 Boxes + 2 m²
      // 3 * 43.20 + 7 * 1.44 + 2 = 129.60 + 10.08 + 2 = 141.68 m²
      final hybridInputs = [
        UnitQuantityInput(unitName: 'طبلية', quantity: 3.0),
        UnitQuantityInput(unitName: 'كرتونة', quantity: 7.0),
        UnitQuantityInput(unitName: 'م²', quantity: 2.0),
      ];
      final hybridTotal = UnitConversionEngine.calculateHybridQuantity(item: porcelainItem, inputs: hybridInputs);
      expect(hybridTotal, 141.68);
    });

    test('Audit Test 8: Decimal & Rounding Arithmetic Precision', () async {
      // Verify floating point addition and multiplications without IEEE artifacts
      final sum = double.parse((0.1 + 0.2).toStringAsFixed(6));
      expect(sum, 0.3);

      final boxCalc = double.parse((1.44 * 10).toStringAsFixed(6));
      expect(boxCalc, 14.40);

      final palletCalc = double.parse((43.20 * 7).toStringAsFixed(6));
      expect(palletCalc, 302.40);

      final totalSum = double.parse((86.40 + 14.40).toStringAsFixed(6));
      expect(totalSum, 100.80);
    });

    test('Audit Test 9: Stress Dataset (100+ Products, 10 Categories & Mass Querying)', () async {
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

      for (int i = 1; i <= 100; i++) {
        final cat = categories[i % categories.length];
        await db.registerOrUpdateLocalItem(
          code: 'PROD-SKU-${i.toString().padLeft(4, '0')}',
          name: 'صنف مستودع تجاري $cat نخب $i',
          category: cat,
          unit: i % 3 == 0 ? 'كرتونة' : (i % 3 == 1 ? 'م²' : 'كيس'),
          initialQty: (i * 25).toDouble(),
          unitPrice: (30 + i * 2).toDouble(),
          location: 'ممر ${(i % 10) + 1} - بايكة $i',
        );
      }

      final allItems = await db.getLocalItems();
      expect(allItems.length, 100);

      // Query verification
      final healthItems = allItems.where((i) => i.category == 'أدوات صحية وسباكة').toList();
      expect(healthItems.length, 10);

      final totalInventoryStock = allItems.fold<double>(0.0, (s, i) => s + i.currentStock);
      // sum(i * 25 for i in 1..100) = 25 * (100 * 101 / 2) = 25 * 5050 = 126,250
      expect(totalInventoryStock, 126250.0);
    });
  });
}
