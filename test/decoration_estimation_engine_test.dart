import 'package:flutter_test/flutter_test.dart';
import 'package:benaa_flutter_mobile/core/services/decoration_estimation_engine.dart';
import 'package:benaa_flutter_mobile/data/models/item_model.dart';

void main() {
  group('DecorationEstimationEngine Comprehensive Suite', () {
    // -------------------------------------------------------------
    // 1. WPC Fluted Wood Panels Tests
    // -------------------------------------------------------------
    test('WPC Wood Estimation: 4.0m width x 2.8m height with 16cm panels', () {
      final estimate = DecorationEstimationEngine.estimateWpcWoodProject(
        wallWidthM: 4.0,
        wallHeightM: 2.8,
        panelWidthCm: 16.0,
        panelLengthM: 2.9,
        wastageRate: 0.05,
      );

      expect(estimate.projectType, DecorationProjectType.wpcWood);
      expect(estimate.items.length, 3); // Panels, Trims, Glue

      final mainPanel = estimate.items.firstWhere((i) => i.role == DecorationItemRole.mainPanel);
      // 400cm / 16cm = 25 panels * 1.05 = 26.25 -> 27 panels
      expect(mainPanel.quantity, 27.0);
      expect(mainPanel.fullCartons, 1); // 27 / 14 = 1 carton
      expect(mainPanel.loosePieces, 13); // 27 % 14 = 13 loose

      final edgeTrim = estimate.items.firstWhere((i) => i.role == DecorationItemRole.edgeTrim);
      expect(edgeTrim.quantity >= 2.0, true);

      final adhesive = estimate.items.firstWhere((i) => i.role == DecorationItemRole.adhesive);
      // 27 / 3.5 = 7.71 -> 8 tubes
      expect(adhesive.quantity, 8.0);
    });

    // -------------------------------------------------------------
    // 2. PVC Marble Sheets Tests
    // -------------------------------------------------------------
    test('PVC Marble Estimation: 3.66m width x 2.8m height (3 sheets wall)', () {
      final estimate = DecorationEstimationEngine.estimatePvcMarbleProject(
        wallWidthM: 3.66,
        wallHeightM: 2.8,
        sheetWidthM: 1.22,
        sheetHeightM: 2.80,
        wastageRate: 0.05,
      );

      expect(estimate.projectType, DecorationProjectType.pvcMarble);

      final sheets = estimate.items.firstWhere((i) => i.role == DecorationItemRole.mainPanel);
      // (3.66 * 2.8) / (1.22 * 2.8) = 3 sheets * 1.05 = 3.15 -> 4 sheets
      expect(sheets.quantity, 4.0);

      // H-Profiles between sheets: (3.66 / 1.22).floor() - 1 = 2 profiles
      final hProfiles = estimate.items.where((i) => i.role == DecorationItemRole.crossProfile);
      expect(hProfiles.isNotEmpty, true);
      expect(hProfiles.first.quantity, 2.0);

      final glue = estimate.items.firstWhere((i) => i.role == DecorationItemRole.adhesive);
      // 4 / 1.5 = 2.66 -> 3 tubes
      expect(glue.quantity, 3.0);
    });

    // -------------------------------------------------------------
    // 3. Wall Foam Frames Tests
    // -------------------------------------------------------------
    test('Foam Frames Estimation: 6 frames of 1.2m x 0.8m', () {
      final estimate = DecorationEstimationEngine.estimateFoamFramesProject(
        frameCount: 6,
        frameWidthM: 1.2,
        frameHeightM: 0.8,
        stickLengthM: 2.4,
        wastageRate: 0.10,
      );

      expect(estimate.projectType, DecorationProjectType.wallFoam);

      // Perimeter per frame = 2 * (1.2 + 0.8) = 4.0m
      // Total linear meters = 6 * 4.0 = 24.0m
      // With 10% wastage = 26.4m / 2.4m = 11 sticks
      final sticks = estimate.items.firstWhere((i) => i.role == DecorationItemRole.mainStructure);
      expect(sticks.quantity, 11.0);

      // 6 frames * 4 corners = 24 corners
      final corners = estimate.items.firstWhere((i) => i.role == DecorationItemRole.edgeTrim);
      expect(corners.quantity, 24.0);

      // Filler: 24m / 20 = 2 cans
      final filler = estimate.items.firstWhere((i) => i.role == DecorationItemRole.filler);
      expect(filler.quantity, 2.0);
    });

    // -------------------------------------------------------------
    // 4. Suspended Ceiling Tests
    // -------------------------------------------------------------
    test('Ceiling Estimation: 100m² verification', () {
      final estimate = DecorationEstimationEngine.estimateCeilingProject(100.0);

      expect(estimate.projectType, DecorationProjectType.ceiling);
      expect(estimate.items.length, 5);

      final tiles = estimate.items.firstWhere((i) => i.itemName.contains('بلاط'));
      expect(tiles.quantity, 275.0);
      expect(tiles.fullCartons, 34);
      expect(tiles.loosePieces, 3);

      final mainTees = estimate.items.firstWhere((i) => i.itemName.contains('جسر'));
      expect(mainTees.quantity, 22.0);

      final wallAngles = estimate.items.firstWhere((i) => i.itemName.contains('زاوية'));
      expect(wallAngles.quantity, 22.0);

      final cross60 = estimate.items.firstWhere((i) => i.itemName.contains('60 سم'));
      expect(cross60.quantity, 125.0);

      final cross120 = estimate.items.firstWhere((i) => i.itemName.contains('120 سم'));
      expect(cross120.quantity, 125.0);
    });

    // -------------------------------------------------------------
    // 5. Item Matching Test
    // -------------------------------------------------------------
    test('Smart item matching against local warehouse inventory', () {
      final List<ItemModel> mockWarehouse = [
        ItemModel(
          code: '154',
          name: 'بلاط دبيس 60*60 جبس سقف مستعار',
          category: 'جبس وأسقف',
          legacyUnit: 'حبة',
          legacyPackagingUnit: 'كرتونة',
          legacyConversionFactor: 8.0,
          currentStock: 1000.0,
          unitPrice: 6.5,
          location: 'ممر A',
        ),
        ItemModel(
          code: '901',
          name: 'شريحة بديل خشب تركي بني مضلع',
          category: 'بدائل الخشب والرخام',
          legacyUnit: 'شريحة',
          legacyPackagingUnit: 'كرتونة',
          legacyConversionFactor: 14.0,
          currentStock: 250.0,
          unitPrice: 39.0,
          location: 'ممر D',
        ),
      ];

      final wpcEstimate = DecorationEstimationEngine.estimateWpcWoodProject(wallWidthM: 3.0, wallHeightM: 2.8);
      final matchedWpc = DecorationEstimationEngine.findMatchingWarehouseItem(wpcEstimate.items.first, mockWarehouse);
      expect(matchedWpc, isNotNull);
      expect(matchedWpc?.code, '901');

      final ceilingEstimate = DecorationEstimationEngine.estimateCeilingProject(50.0);
      final matchedCeiling = DecorationEstimationEngine.findMatchingWarehouseItem(ceilingEstimate.items.first, mockWarehouse);
      expect(matchedCeiling, isNotNull);
      expect(matchedCeiling?.code, '154');
    });
  });
}
