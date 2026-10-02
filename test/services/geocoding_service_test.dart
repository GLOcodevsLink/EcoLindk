import 'dart:convert';

import 'package:ecolindk/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  GeocodingService service(MockClientHandler handler) =>
      GeocodingService(client: MockClient(handler));

  test('queries Nominatim restricted to Cameroon and parses the first result', () async {
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

  test('empty address: no request', () async {
    await expectLater(service((_) async => fail('ne doit pas appeler')).geocode('   '),
        throwsCode('empty-address'));
  });

  test('no result → not-found', () async {
    await expectLater(
        service((_) async => http.Response('[]', 200)).geocode('xyz'), throwsCode('not-found'));
  });

  test('unreadable coordinates → not-found', () async {
    await expectLater(
        service((_) async => http.Response(
            jsonEncode([
              {'lat': 'a', 'lon': 'b'}
            ]),
            200)).geocode('xyz'),
        throwsCode('not-found'));
  });

  test('HTTP ≠ 200 → http-error', () async {
    await expectLater(
        service((_) async => http.Response('', 503)).geocode('xyz'), throwsCode('http-error'));
  });

  test('non-JSON response → http-error', () async {
    await expectLater(service((_) async => http.Response('<html>', 200)).geocode('xyz'),
        throwsCode('http-error'));
  });

  test('no network → network', () async {
    await expectLater(service((_) async => throw http.ClientException('offline')).geocode('xyz'),
        throwsCode('network'));
  });
}
