import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/services/nearby_posts.dart';
import 'package:ecolindk/services/zone_matching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;

// Quartiers de Yaoundé (coordonnées approximatives) et Douala.
const bastos = (3.8950, 11.5100);
const mvan = (3.8200, 11.5250);
const essos = (3.8700, 11.5350);
const nkolbisson = (3.8700, 11.4400);
const akwaDouala = (4.0500, 9.7000);

Map<String, dynamic> zone(String name, (double, double) p, {String city = 'Yaoundé'}) =>
    {'city': city, 'neighborhood': name, 'latitude': p.$1, 'longitude': p.$2};

CollectionRequest post(String id, (double, double) p) => CollectionRequest(
      id: id,
      householdUid: 'h',
      householdName: '',
      imageUrl: '',
      description: '',
      category: WasteCategory.plastic,
      quantityRange: '5 kg',
      aiRequested: false,
      address: '',
      latitude: p.$1,
      longitude: p.$2,
      locationIsApproximate: false,
      status: RequestStatus.pending,
      createdAt: DateTime(2026),
    );

void main() {
  group('ciblage des notifications par zones de collecte', () {
    final collectors = {
      'A': {
        'zones': [zone('Mvan', mvan), zone('Bastos', bastos), zone('Essos', essos)]
      },
      'D': {
        'zones': [zone('Akwa', akwaDouala, city: 'Douala')]
      },
    };

    test('post à Bastos : A notifié une seule fois (plusieurs zones proches), D non', () {
      final matches = collectorsForPost(
          latitude: bastos.$1, longitude: bastos.$2, city: 'Yaoundé', neighborhood: 'Bastos',
          collectorLocations: collectors);
      expect(matches.map((m) => m.collectorUid), ['A']);
      expect(matches.single.zoneName, 'Bastos');
      expect(matches.single.distanceKm, lessThan(0.1));
    });

    test('post hors des zones (Nkolbisson, ~7 km de la zone la plus proche) : personne', () {
      final matches = collectorsForPost(
          latitude: nkolbisson.$1, longitude: nkolbisson.$2, city: 'Yaoundé', neighborhood: 'Nkolbisson',
          collectorLocations: collectors);
      expect(matches, isEmpty);
    });

    test('même quartier et même ville : éligible même sans coordonnées', () {
      final matches = collectorsForPost(
        latitude: nkolbisson.$1,
        longitude: nkolbisson.$2,
        city: 'Yaoundé',
        neighborhood: 'Nkolbisson',
        collectorLocations: {
          'B': {
            'zones': [
              {'city': 'Yaoundé', 'neighborhood': 'Nkolbisson', 'latitude': null, 'longitude': null}
            ]
          }
        },
      );
      expect(matches.single.collectorUid, 'B');
      expect(matches.single.distanceKm, isNull);
    });

    test('rayon réglable', () {
      final far = collectorsForPost(
          latitude: nkolbisson.$1, longitude: nkolbisson.$2, collectorLocations: collectors, radiusKm: 12);
      expect(far.map((m) => m.collectorUid), ['A']);
    });

    test('ancien document (un seul point, sans zones) toujours pris en compte', () {
      final matches = collectorsForPost(
        latitude: bastos.$1,
        longitude: bastos.$2,
        collectorLocations: {
          'old': {'latitude': 3.90, 'longitude': 11.51}
        },
      );
      expect(matches.single.collectorUid, 'old');
    });
  });

  group('recherche "Autour de moi" par GPS actuel', () {
    final posts = [post('bastos', bastos), post('nkol', nkolbisson), post('douala', akwaDouala)];

    test('collecteur à Nkolbisson (hors de ses zones) : trouve les posts autour de lui', () {
      final found = postsAroundPosition(posts, ll.LatLng(nkolbisson.$1, nkolbisson.$2), radiusKm: 5);
      expect(found.map((e) => e.$1.id), ['nkol']);
    });

    test('trié du plus proche au plus loin, Douala exclu', () {
      final found = postsAroundPosition(posts, ll.LatLng(nkolbisson.$1, nkolbisson.$2), radiusKm: 20);
      expect(found.map((e) => e.$1.id), ['nkol', 'bastos']);
      expect(found.first.$2, lessThan(found.last.$2));
    });
  });
}
