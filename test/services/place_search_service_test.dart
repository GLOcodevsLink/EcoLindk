import 'dart:convert';

import 'package:ecolindk/services/geocoding_service.dart';
import 'package:ecolindk/services/place_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Un résultat au format de l'API Photon.
Map<String, dynamic> feature(String name, String key, String value,
        {String cc = 'CM', String country = 'Cameroun', String? type, List<double>? extent, double lat = 3.87, double lon = 11.52}) =>
    {
      'type': 'Feature',
      'geometry': {'type': 'Point', 'coordinates': [lon, lat]},
      'properties': {
        'name': name,
        'osm_key': key,
        'osm_value': value,
        'countrycode': cc,
        'country': country,
        if (type != null) 'type': type,
        if (extent != null) 'extent': extent,
      },
    };

http.Response photon(List<Map<String, dynamic>> features) =>
    http.Response.bytes(utf8.encode(jsonEncode({'type': 'FeatureCollection', 'features': features})), 200);

const yaounde = PlaceResult(
  name: 'Yaoundé',
  city: '',
  country: 'Cameroun',
  countryCode: 'CM',
  latitude: 3.8689,
  longitude: 11.5213,
  bbox: [11.4111836, 3.7134029, 11.5748061, 3.9691958],
);

void main() {
  group('villes', () {
    test('"Yaou" : villes du pays choisi, avec coordonnées et emprise', () async {
      late Uri sent;
      final s = PlaceSearchService(client: MockClient((req) async {
        sent = req.url;
        return photon([
          feature('Yaoundé', 'place', 'city',
              extent: [11.4111836, 3.9691958, 11.5748061, 3.7134029], lat: 3.8689, lon: 11.5213),
          feature('Yaouri', 'place', 'town', cc: 'TD', country: 'Tchad'),
        ]);
      }));

      final cities = await s.searchCities('Yaou', countryCode: 'CM');

      expect(cities.map((c) => c.name), ['Yaoundé']);
      expect(cities.single.latitude, 3.8689);
      expect(cities.single.longitude, 11.5213);
      // Emprise remise dans l'ordre [ouest, sud, est, nord].
      expect(cities.single.bbox, [11.4111836, 3.7134029, 11.5748061, 3.9691958]);
      expect(sent.queryParametersAll['osm_tag'], containsAll(['place:city', 'place:town']));
      expect(sent.queryParameters['q'], 'Yaou');
    });

    test('moins de 2 lettres : aucune requête', () async {
      final s = PlaceSearchService(client: MockClient((_) async => fail('ne doit pas appeler')));
      expect(await s.searchCities(' Y '), isEmpty);
      expect(await s.searchCities(''), isEmpty);
    });
  });

  group('quartiers', () {
    test('ne garde que les vrais quartiers de la ville, sans doublon', () async {
      late Uri sent;
      final s = PlaceSearchService(client: MockClient((req) async {
        sent = req.url;
        return photon([
          feature('bas', 'leisure', 'pitch'),
          feature('Bastos', 'boundary', 'administrative', type: 'district', lat: 3.895, lon: 11.51),
          feature('Mini prix Bastos', 'place', 'locality', type: 'locality'),
          feature('Nouvelle Route Bastos', 'highway', 'secondary'),
          feature('Nkolbisson', 'place', 'village', type: 'district'),
          feature('Nkolbisson', 'boundary', 'administrative', type: 'district'),
        ]);
      }));

      final results = await s.searchNeighborhoods('Bas', city: yaounde);

      expect(results.map((r) => r.name), ['Bastos', 'Nkolbisson']);
      final bastos = results.first;
      expect(bastos.city, 'Yaoundé');
      expect(bastos.countryCode, 'CM');
      expect(bastos.latitude, 3.895);
      expect(bastos.longitude, 11.51);
      // Recherche limitée à l'emprise de la ville.
      expect(sent.queryParameters['bbox'], '11.4111836,3.7134029,11.5748061,3.9691958');
    });

    test('aucun résultat → liste vide', () async {
      final s = PlaceSearchService(client: MockClient((_) async => photon(const [])));
      expect(await s.searchNeighborhoods('Zzz', city: yaounde), isEmpty);
    });
  });

  group('erreurs', () {
    test('pas de réseau → network', () async {
      final s = PlaceSearchService(client: MockClient((_) async => throw http.ClientException('offline')));
      await expectLater(s.searchCities('Yaou'),
          throwsA(isA<PlaceSearchException>().having((e) => e.code, 'code', 'network')));
    });

    test('erreur serveur → http-error', () async {
      final s = PlaceSearchService(client: MockClient((_) async => http.Response('', 503)));
      await expectLater(s.searchCities('Yaou'),
          throwsA(isA<PlaceSearchException>().having((e) => e.code, 'code', 'http-error')));
    });
  });

  group('géocodage inverse du post (Nominatim)', () {
    test('coordonnées → quartier et ville', () async {
      final g = GeocodingService(client: MockClient((req) async {
        expect(req.url.path, '/reverse');
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'address': {'suburb': 'Bastos', 'city_district': 'Yaoundé I', 'city': 'Yaoundé', 'country': 'Cameroun'}
            })),
            200);
      }));
      final r = await g.reverse(3.895, 11.51);
      expect(r!.neighborhood, 'Bastos');
      expect(r.city, 'Yaoundé');
    });

    test('erreur réseau → null, jamais bloquant', () async {
      final g = GeocodingService(client: MockClient((_) async => throw http.ClientException('offline')));
      expect(await g.reverse(3.895, 11.51), isNull);
    });
  });
}
