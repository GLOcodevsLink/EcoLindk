import 'package:ecolindk/core/rewards_config.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardsConfig', () {
    test('every category has a points rate and a price', () async {
      for (final c in WasteCategory.values) {
        expect(RewardsConfig.pointsPerKg[c], isNotNull, reason: c.name);
        expect(RewardsConfig.pricePerKgFcfa[c], isNotNull, reason: c.name);
      }
    });

    test('15 points are worth 500 FCFA', () async {
      expect(RewardsConfig.fcfaForPoints(15), 500);
      expect(RewardsConfig.fcfaForPoints(30), 1000);
      expect(RewardsConfig.fcfaForPoints(0), 0);
    });

    test('collection points = rate shown on Conversion rates × weight', () async {
      // Bouteilles plastique 3 P/kg, métal 6 P/kg, verre 0,5 P/kg, carton 2 P/kg.
      expect(RewardsConfig.pointsForCollection(WasteCategory.plastic, 11), 33);
      expect(RewardsConfig.pointsForCollection(WasteCategory.metal, 1.5), 9);
      expect(RewardsConfig.pointsForCollection(WasteCategory.glass, 4), 2);
      expect(RewardsConfig.pointsForCollection(WasteCategory.paperCardboard, 5), 10);
    });

    test('exactly one displayed rate row per credited category', () async {
      for (final c in WasteCategory.values) {
        final rows = RewardsConfig.referenceMaterials.where((m) => m.creditedCategory == c);
        expect(rows.length, 1, reason: c.name);
        expect(RewardsConfig.pointsPerKg[c], rows.single.pointsPerKg);
      }
    });

    test('collection value = price per kg × weight', () async {
      expect(RewardsConfig.valueForCollection(WasteCategory.plastic, 4), 300);
      expect(RewardsConfig.valueForCollection(WasteCategory.metal, 1), 100);
      expect(RewardsConfig.valueForCollection(WasteCategory.beverageCans, 1), 200);
    });

    test('the detailed rate table derives from the same conversion rate', () async {
      for (final m in RewardsConfig.referenceMaterials) {
        expect(m.fcfaPerKg(), RewardsConfig.fcfaForPoints(m.pointsPerKg));
        expect(m.label(true), isNotEmpty);
        expect(m.label(false), isNotEmpty);
      }
    });
  });
}
