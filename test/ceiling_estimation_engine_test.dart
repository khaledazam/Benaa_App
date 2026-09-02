import 'package:flutter_test/flutter_test.dart';
import 'package:benaa_flutter_mobile/core/services/ceiling_estimation_engine.dart';

void main() {
  group('CeilingEstimationEngine Tests', () {
    test('100 m² Project Estimation Formula Verification', () {
      final estimate = CeilingEstimationEngine.calculateFullProject(100.0);

      // Gypsum Tiles: 100 * 2.75 = 275 tiles -> 34 cartons (272) + 3 loose
      expect(estimate.gypsumTiles.totalPieces, 275.0);
      expect(estimate.gypsumTiles.fullCartons, 34);
      expect(estimate.gypsumTiles.loosePieces, 3);
      expect(estimate.gypsumTiles.shortSummary, '34 ك + 3 حبة');

      // Main Tees: 100 * 0.22 = 22 pcs -> 0 cartons + 22 loose
      expect(estimate.mainTees.totalPieces, 22.0);
      expect(estimate.mainTees.fullCartons, 0);
      expect(estimate.mainTees.loosePieces, 22);

      // Wall Angles: 100 * 0.22 = 22 pcs -> 0 cartons + 22 loose
      expect(estimate.wallAngles.totalPieces, 22.0);
      expect(estimate.wallAngles.fullCartons, 0);
      expect(estimate.wallAngles.loosePieces, 22);

      // Cross Tees 60: 100 * 1.25 = 125 pcs -> 1 carton (75) + 50 loose
      expect(estimate.crossTees60.totalPieces, 125.0);
      expect(estimate.crossTees60.fullCartons, 1);
      expect(estimate.crossTees60.loosePieces, 50);

      // Cross Tees 120: 100 * 1.25 = 125 pcs -> 1 carton (75) + 50 loose
      expect(estimate.crossTees120.totalPieces, 125.0);
      expect(estimate.crossTees120.fullCartons, 1);
      expect(estimate.crossTees120.loosePieces, 50);
    });

    test('300 m² Project Estimation Formula Verification', () {
      final estimate = CeilingEstimationEngine.calculateFullProject(300.0);

      // Gypsum Tiles: 300 * 2.75 = 825 tiles -> 103 cartons (824) + 1 loose
      expect(estimate.gypsumTiles.totalPieces, 825.0);
      expect(estimate.gypsumTiles.fullCartons, 103);
      expect(estimate.gypsumTiles.loosePieces, 1);

      // Main Tees: 300 * 0.22 = 66 pcs -> 2 cartons (50) + 16 loose
      expect(estimate.mainTees.totalPieces, 66.0);
      expect(estimate.mainTees.fullCartons, 2);
      expect(estimate.mainTees.loosePieces, 16);

      // Wall Angles: 300 * 0.22 = 66 pcs -> 1 carton (50) + 16 loose
      expect(estimate.wallAngles.totalPieces, 66.0);
      expect(estimate.wallAngles.fullCartons, 1);
      expect(estimate.wallAngles.loosePieces, 16);

      // Cross Tees 60: 300 * 1.25 = 375 pcs -> 5 full cartons (375) + 0 loose
      expect(estimate.crossTees60.totalPieces, 375.0);
      expect(estimate.crossTees60.fullCartons, 5);
      expect(estimate.crossTees60.loosePieces, 0);
    });
  });
}
