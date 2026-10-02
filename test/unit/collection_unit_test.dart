import 'package:ecolindk/core/rewards_config.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/models/household_stats.dart';
import 'package:ecolindk/services/nearby_posts.dart';
import 'package:ecolindk/services/zone_matching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;

/// Tests unitaires du module Collecte : chaque test vérifie une seule
/// classe ou fonction, sans base de données ni réseau.

const bastos = (3.8950, 11.5100);
const nkolbisson = (3.8700, 11.4400);

CollectionRequest request({
  String id = 'abcdef123',
  String quantity = '6 kg',
  RequestStatus status = RequestStatus.accepted,
  String? scanCode,
  (double, double) at = bastos,
  double? weightKg,
  int? points,
  DateTime? completedAt,
  WasteCategory category = WasteCategory.plastic,
}) =>
    CollectionRequest(
      id: id,
      householdUid: 'supplier',
      householdName: 'Awa',
      imageUrl: '',
      description: '',
      category: category,
      quantityRange: quantity,
      aiRequested: false,
      address: '',
      latitude: at.$1,
      longitude: at.$2,
      locationIsApproximate: false,
      status: status,
      scanCode: scanCode,
      weightKg: weightKg,
      pointsEarned: points,
      createdAt: DateTime(2026, 9, 1),
      completedAt: completedAt,
    );

Map<String, dynamic> zone(String name, (double, double) p) =>
    {'city': 'Yaoundé', 'neighborhood': name, 'latitude': p.$1, 'longitude': p.$2};

void main() {
  group('Weighed weight check', () {
    test('a weight up to 5 kg away from the declared weight is accepted', () {
      expect('6 kg'.acceptsCollectedWeight(11), isTrue);
      expect('6 kg'.acceptsCollectedWeight(1), isTrue);
      expect('6 kg'.acceptsCollectedWeight(6), isTrue);
    });

    test('a weight more than 5 kg away is refused', () {
      expect('6 kg'.acceptsCollectedWeight(11.5), isFalse);
      expect('6 kg'.acceptsCollectedWeight(0.5), isFalse);
    });

    test('a zero or negative weight is refused', () {
      expect('6 kg'.acceptsCollectedWeight(0), isFalse);
      expect('6 kg'.acceptsCollectedWeight(-2), isFalse);
    });

    test('the accepted range is shown to the collector', () {
      expect('6 kg'.weightBoundsKg, (1, 11));
      expect('2,5 kg'.weightBoundsKg, (0, 7.5));
    });
  });

  group('Points and commission', () {
    test('the supplier earns the displayed rate × confirmed weight', () {
      expect(RewardsConfig.pointsForCollection(WasteCategory.plastic, 7), 21);
    });

    test('the collector commission is the commission rate × confirmed weight', () {
      expect(RewardsConfig.commissionForCollection(WasteCategory.plastic, 7), 70);
      expect(RewardsConfig.commissionForCollection(WasteCategory.metal, 2), 40);
    });

    test('beverage cans: 2 points per kg, same commission as glass', () {
      expect(RewardsConfig.pointsPerKg[WasteCategory.beverageCans], 2);
      expect(RewardsConfig.pointsForCollection(WasteCategory.beverageCans, 3), 6);
      expect(RewardsConfig.commissionPerKgFcfa[WasteCategory.beverageCans],
          RewardsConfig.commissionPerKgFcfa[WasteCategory.glass]);
    });

    test('the price list shows beverage cans at 2 points per kg', () {
      final row = RewardsConfig.referenceMaterials.singleWhere((m) => m.creditedCategory == WasteCategory.beverageCans);
      expect(row.labelEn, 'Beverage cans');
      expect(row.pointsPerKg, 2);
    });

    test('15 points are worth 500 FCFA', () {
      expect(RewardsConfig.fcfaForPoints(15), 500);
      expect(RewardsConfig.fcfaForPoints(21), 700);
    });
  });

  group('Collection QR code', () {
    test('the QR code contains the collection and its one-time code', () {
      final r = request(scanCode: 'K7Q2M9XH4P');
      expect(r.qrPayload, 'ecolindk:collection:abcdef123:K7Q2M9XH4P');
    });

    test('the collection reference is short and readable', () {
      expect(request().reference, 'ECL-ABCDEF');
    });

    test('statuses have labels for the timeline', () {
      expect(RequestStatus.inProgress.label(false), 'Awaiting confirmation');
      expect(RequestStatus.completed.label(false), 'Completed');
    });
  });

  group('Collector notification by collection zone', () {
    final collectors = {
      'A': {
        'zones': [zone('Bastos', bastos), zone('Essos', (3.8700, 11.5350))]
      },
      'D': {
        'zones': [
          {'city': 'Douala', 'neighborhood': 'Akwa', 'latitude': 4.05, 'longitude': 9.70}
        ]
      },
    };

    test('a collector with a zone within 5 km is notified, only once', () {
      final matches = collectorsForPost(
          latitude: bastos.$1, longitude: bastos.$2, collectorLocations: collectors);
      expect(matches.map((m) => m.collectorUid), ['A']);
    });

    test('a collector whose zones are far away is not notified', () {
      final matches = collectorsForPost(
          latitude: nkolbisson.$1, longitude: nkolbisson.$2, collectorLocations: collectors);
      expect(matches, isEmpty);
    });

    test('same neighborhood and same city also counts', () {
      final matches = collectorsForPost(
        latitude: nkolbisson.$1,
        longitude: nkolbisson.$2,
        city: 'Yaoundé',
        neighborhood: 'Nkolbisson',
        collectorLocations: {
          'B': {
            'zones': [
              {'city': 'Yaoundé', 'neighborhood': 'Nkolbisson'}
            ]
          }
        },
      );
      expect(matches.single.collectorUid, 'B');
    });
  });

  group('Around me search (current GPS)', () {
    final posts = [request(id: 'bastos1', at: bastos), request(id: 'nkol1', at: nkolbisson)];

    test('keeps only the posts within the radius', () {
      final found = postsAroundPosition(posts, ll.LatLng(nkolbisson.$1, nkolbisson.$2), radiusKm: 5);
      expect(found.map((e) => e.$1.id), ['nkol1']);
    });

    test('sorts the posts from nearest to farthest', () {
      final found = postsAroundPosition(posts, ll.LatLng(nkolbisson.$1, nkolbisson.$2), radiusKm: 20);
      expect(found.map((e) => e.$1.id), ['nkol1', 'bastos1']);
    });
  });

  group('Supplier statistics after collections', () {
    test('counts completed collections, kg and points', () {
      final stats = HouseholdStats.from([
        request(status: RequestStatus.completed, weightKg: 7, points: 21, completedAt: DateTime(2026, 9, 29)),
        request(status: RequestStatus.pending),
        request(status: RequestStatus.cancelled),
      ], now: DateTime(2026, 9, 29, 12));
      expect(stats.completedCount, 1);
      expect(stats.inProgressCount, 1);
      expect(stats.cancelledCount, 1);
      expect(stats.totalKg, 7);
      expect(stats.totalPoints, 21);
      expect(stats.last7Days.last.kg, 7);
    });
  });
}
