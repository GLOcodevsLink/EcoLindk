import 'package:ecolindk/core/rewards_config.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardsConfig', () {
    test('chaque catégorie a un barème de points et un prix', () async {
      for (final c in WasteCategory.values) {
        expect(RewardsConfig.pointsPerKg[c], isNotNull, reason: c.name);
        expect(RewardsConfig.pricePerKgFcfa[c], isNotNull, reason: c.name);
      }
    });

    test('15 points valent 500 FCFA', () async {
      expect(RewardsConfig.fcfaForPoints(15), 500);
      expect(RewardsConfig.fcfaForPoints(30), 1000);
      expect(RewardsConfig.fcfaForPoints(0), 0);
    });

    test('points d\'une collecte = taux affiché sur "Taux de conversion" × poids', () async {
      // Bouteilles plastique 3 P/kg, métal 6 P/kg, verre 0,5 P/kg, carton 2 P/kg.
      expect(RewardsConfig.pointsForCollection(WasteCategory.plastic, 11), 33);
      expect(RewardsConfig.pointsForCollection(WasteCategory.metal, 1.5), 9);
      expect(RewardsConfig.pointsForCollection(WasteCategory.glass, 4), 2);
      expect(RewardsConfig.pointsForCollection(WasteCategory.paperCardboard, 5), 10);
    });

    test('une seule ligne du barème affiché par catégorie créditée', () async {
      for (final c in WasteCategory.values) {
        final rows = RewardsConfig.referenceMaterials.where((m) => m.creditedCategory == c);
        expect(rows.length, 1, reason: c.name);
        expect(RewardsConfig.pointsPerKg[c], rows.single.pointsPerKg);
      }
    });

    test('valeur d\'une collecte = prix/kg × poids', () async {
      expect(RewardsConfig.valueForCollection(WasteCategory.plastic, 4), 300);
      expect(RewardsConfig.valueForCollection(WasteCategory.metal, 1), 200);
    });

    test('le barème détaillé dérive du même taux de conversion', () async {
      for (final m in RewardsConfig.referenceMaterials) {
        expect(m.fcfaPerKg(), RewardsConfig.fcfaForPoints(m.pointsPerKg));
        expect(m.label(true), isNotEmpty);
        expect(m.label(false), isNotEmpty);
      }
    });
  });
}
