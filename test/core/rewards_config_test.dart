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

    test('points d\'une collecte = points/kg × poids', () async {
      expect(RewardsConfig.pointsForCollection(WasteCategory.plastic, 2), 20);
      expect(RewardsConfig.pointsForCollection(WasteCategory.metal, 1.5), 22.5);
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
