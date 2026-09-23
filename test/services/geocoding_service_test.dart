import 'dart:convert';

import 'package:ecolindk/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  GeocodingService service(MockClientHandler handler) =>
      GeocodingService(client: MockClient(handler));

  test('interroge Nominatim limité au Cameroun et parse le premier résultat', () async {
    late http.Request sent;
    final result = await service((req) async {
      sent = req;
      return http.Response(
          jsonEncode([
            {'lat': '4.0511', 'lon': '9.7679', 'display_name': 'Akwa, Douala'}
          ]),
          200);
    }).geocode('  Akwa  ');

    expect(sent.url.host, 'nominatim.openstreetmap.org');
    expect(sent.url.queryParameters['q'], 'Akwa');
    expect(sent.url.queryParameters['countrycodes'], 'cm');
    expect(sent.url.queryParameters['limit'], '1');
    expect(sent.headers['User-Agent'], startsWith('EcoLindk'));
    expect(result.latitude, 4.0511);
    expect(result.longitude, 9.7679);
    expect(result.displayName, 'Akwa, Douala');
  });

  Matcher throwsCode(String code) =>
      throwsA(isA<GeocodingException>().having((e) => e.code, 'code', code));

  test('adresse vide : aucune requête', () {
    expect(service((_) async => fail('ne doit pas appeler')).geocode('   '),
        throwsCode('empty-address'));
  });

  test('aucun résultat → not-found', () {
    expect(service((_) async => http.Response('[]', 200)).geocode('xyz'),
        throwsCode('not-found'));
  });

  test('coordonnées illisibles → not-found', () {
    expect(
        service((_) async => http.Response(jsonEncode([{'lat': 'a', 'lon': 'b'}]), 200))
            .geocode('xyz'),
        throwsCode('not-found'));
  });

  test('HTTP ≠ 200 → http-error', () {
    expect(service((_) async => http.Response('', 503)).geocode('xyz'),
        throwsCode('http-error'));
  });

  test('réponse non JSON → http-error', () {
    expect(service((_) async => http.Response('<html>', 200)).geocode('xyz'),
        throwsCode('http-error'));
  });

  test('pas de réseau → network', () {
    expect(service((_) async => throw http.ClientException('offline')).geocode('xyz'),
        throwsCode('network'));
  });
}
