import 'package:flutter_test/flutter_test.dart';
import 'package:benaa_flutter_mobile/data/models/item_model.dart';
import 'package:benaa_flutter_mobile/data/models/product_unit_model.dart';
import 'package:benaa_flutter_mobile/core/services/unit_conversion_engine.dart';

void main() {
  group('Enterprise UnitConversionEngine Tests', () {
    late ItemModel screwProduct;
    late ItemModel ceramicProduct;
    late ItemModel steelProduct;

    setUp(() {
      // 1. Screws Product (Piece -> Box 24 -> Carton 240)
      screwProduct = ItemModel(
        code: '101',
        name: 'مسامير ربطة',
        category: 'مسامير وتثبيت',
        legacyUnit: 'حبة',
        currentStock: 1000.0,
        units: [
          ProductUnitModel(id: 'u1', productCode: '101', unitName: 'حبة', unitType: UnitType.count, conversionFactor: 1.0, isBase: true),
          ProductUnitModel(id: 'u2', productCode: '101', unitName: 'علبة', unitType: UnitType.packaging, conversionFactor: 24.0),
          ProductUnitModel(id: 'u3', productCode: '101', unitName: 'كرتونة', unitType: UnitType.packaging, conversionFactor: 240.0),
        ],
      );

      // 2. Ceramic 60x60 Product (m² -> Carton 2.40 -> Pallet 115.20)
      ceramicProduct = ItemModel(
        code: '202',
        name: 'سيراميك 60*60',
        category: 'ألواح وديكورات',
        legacyUnit: 'م²',
        currentStock: 240.0,
        units: [
          ProductUnitModel(id: 'c1', productCode: '202', unitName: 'م²', unitType: UnitType.area, conversionFactor: 1.0, isBase: true),
          ProductUnitModel(id: 'c2', productCode: '202', unitName: 'كرتونة', unitType: UnitType.packaging, conversionFactor: 2.40),
          ProductUnitModel(id: 'c3', productCode: '202', unitName: 'طبلية', unitType: UnitType.packaging, conversionFactor: 115.20),
        ],
      );

      // 3. Steel Product (KG -> Ton 1000)
      steelProduct = ItemModel(
        code: '303',
        name: 'حديد تسليح 12مم',
        category: 'حديد ومعادن',
        legacyUnit: 'كجم',
        currentStock: 5000.0,
        units: [
          ProductUnitModel(id: 's1', productCode: '303', unitName: 'كجم', unitType: UnitType.weight, conversionFactor: 1.0, isBase: true),
          ProductUnitModel(id: 's2', productCode: '303', unitName: 'طن', unitType: UnitType.weight, conversionFactor: 1000.0),
        ],
      );
    });

    test('Test 1 — Basic conversion (3 Cartons = 72 Pieces)', () {
      final baseQty = UnitConversionEngine.convertToBaseUnit(
        item: screwProduct,
        unitName: 'علبة',
        quantity: 3.0,
      );
      expect(baseQty, 72.0);
    });

    test('Test 2 — Hybrid quantity (3 Cartons + 5 Pieces = 77 Pieces)', () {
      final inputs = [
        UnitQuantityInput(unitName: 'علبة', quantity: 3.0),
        UnitQuantityInput(unitName: 'حبة', quantity: 5.0),
      ];
      final totalBaseQty = UnitConversionEngine.calculateHybridQuantity(
        item: screwProduct,
        inputs: inputs,
      );
      expect(totalBaseQty, 77.0);
    });

    test('Test 3 — Weight conversion (2 Tons + 350 KG = 2350 KG)', () {
      final inputs = [
        UnitQuantityInput(unitName: 'طن', quantity: 2.0),
        UnitQuantityInput(unitName: 'كجم', quantity: 350.0),
      ];
      final totalBaseQty = UnitConversionEngine.calculateHybridQuantity(
        item: steelProduct,
        inputs: inputs,
      );
      expect(totalBaseQty, 2350.0);
    });

    test('Test 4 — Area conversion (5 Cartons x 2.40 m² = 12.00 m²)', () {
      final baseQty = UnitConversionEngine.convertToBaseUnit(
        item: ceramicProduct,
        unitName: 'كرتونة',
        quantity: 5.0,
      );
      expect(baseQty, 12.00);
    });

    test('Test 5 — Historical conversion snapshot protection', () {
      // Transaction #1024 at 1 Carton = 2.40 m²
      final snapshot = UnitConversionEngine.createHistoricalSnapshot(
        transactionId: 'INV-1024',
        transactionType: 'SALE',
        item: ceramicProduct,
        enteredUnit: 'كرتونة',
        enteredQuantity: 5.0,
      );

      expect(snapshot.baseQuantity, 12.00);
      expect(snapshot.conversionFactor, 2.40);

      // Now edit product configuration to 1 Carton = 2.50 m²
      final updatedCeramic = ItemModel(
        code: '202',
        name: 'سيراميك 60*60',
        category: 'ألواح وديكورات',
        legacyUnit: 'م²',
        currentStock: 240.0,
        units: [
          ProductUnitModel(id: 'c1', productCode: '202', unitName: 'م²', unitType: UnitType.area, conversionFactor: 1.0, isBase: true),
          ProductUnitModel(id: 'c2', productCode: '202', unitName: 'كرتونة', unitType: UnitType.packaging, conversionFactor: 2.50),
        ],
      );

      // Verify past snapshot remains 12.00 m² and factor 2.40!
      expect(snapshot.baseQuantity, 12.00);
      expect(snapshot.conversionFactor, 2.40);

      // Verify new transaction uses 2.50
      final newBaseQty = UnitConversionEngine.convertToBaseUnit(
        item: updatedCeramic,
        unitName: 'كرتونة',
        quantity: 5.0,
      );
      expect(newBaseQty, 12.50);
    });

    test('Test 6 — Warehouse transfer base quantity calculation', () {
      final transferBaseQty = UnitConversionEngine.convertToBaseUnit(
        item: ceramicProduct,
        unitName: 'طبلية',
        quantity: 2.0,
      );
      expect(transferBaseQty, 230.40); // 2 x 115.20
    });

    test('Test 7 — Stock adjustment hybrid conversion', () {
      final adjustmentInputs = [
        UnitQuantityInput(unitName: 'كرتونة', quantity: 1.0),
        UnitQuantityInput(unitName: 'علبة', quantity: 2.0),
        UnitQuantityInput(unitName: 'حبة', quantity: 4.0),
      ];
      final totalBaseQty = UnitConversionEngine.calculateHybridQuantity(
        item: screwProduct,
        inputs: adjustmentInputs,
      );
      // 1x240 + 2x24 + 4 = 292 Pieces
      expect(totalBaseQty, 292.0);
    });

    test('Test 8 — Decimal quantities support', () {
      final tonBase = UnitConversionEngine.convertToBaseUnit(
        item: steelProduct,
        unitName: 'طن',
        quantity: 0.5,
      );
      expect(tonBase, 500.0);

      final sqmBase = UnitConversionEngine.convertToBaseUnit(
        item: ceramicProduct,
        unitName: 'كرتونة',
        quantity: 1.25,
      );
      expect(sqmBase, 3.0); // 1.25 * 2.40 = 3.0 m²
    });

    test('Test 9 — Invalid unit rejection', () {
      expect(
        () => UnitConversionEngine.convertToBaseUnit(
          item: screwProduct,
          unitName: 'متر',
          quantity: 5.0,
        ),
        throwsArgumentError,
      );
    });

    test('Test 10 — Invalid quantity rejection', () {
      expect(
        () => UnitConversionEngine.calculateHybridQuantity(
          item: screwProduct,
          inputs: [UnitQuantityInput(unitName: 'حبة', quantity: -5.0)],
        ),
        throwsArgumentError,
      );
    });

    test('Test 11 — Inactive unit rejection', () {
      final inactiveProduct = ItemModel(
        code: '404',
        name: 'منتج معطل',
        category: 'عام',
        legacyUnit: 'حبة',
        currentStock: 10.0,
        units: [
          ProductUnitModel(id: 'i1', productCode: '404', unitName: 'حبة', unitType: UnitType.count, conversionFactor: 1.0, isBase: true),
          ProductUnitModel(id: 'i2', productCode: '404', unitName: 'كرتونة', unitType: UnitType.packaging, conversionFactor: 12.0, isActive: false),
        ],
      );

      expect(
        () => UnitConversionEngine.convertToBaseUnit(
          item: inactiveProduct,
          unitName: 'كرتونة',
          quantity: 1.0,
        ),
        throwsStateError,
      );
    });

    test('Test 12 — Formatting quantity by UnitType', () {
      expect(UnitConversionEngine.formatQuantity(quantity: 12.500, unitType: UnitType.weight), '12.5');
      expect(UnitConversionEngine.formatQuantity(quantity: 77.0, unitType: UnitType.count), '77');
    });
  });
}
