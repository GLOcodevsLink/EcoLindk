import 'dart:convert';
import 'dart:io';

import 'package:ecolindk/services/stockimg_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late File photo;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('stockimg_test');
    photo = File('${dir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
  });

  StockImgClient client(MockClientHandler handler, {String baseUrl = 'https://img.test/'}) =>
      StockImgClient(baseUrl: baseUrl, apiKey: 'cle-123', httpClient: MockClient(handler));

  group('uploadFile', () {
    test('envoie le fichier en multipart avec la clé et renvoie l\'URL', () async {
      late http.Request sent;
      final url = await client((req) async {
        sent = req;
        return http.Response(
            jsonEncode({
              'data': {'id': 1, 'url': 'https://img.test/storage/uploads/1/a.jpg'}
            }),
            201);
      }).uploadFile(photo);

      expect(url, 'https://img.test/storage/uploads/1/a.jpg');
      expect(sent.method, 'POST');
      // Le slash final de baseUrl ne doit pas produire "//api".
      expect(sent.url.toString(), 'https://img.test/api/v1/files');
      expect(sent.headers['Authorization'], 'Bearer cle-123');
      expect(sent.headers['content-type'], startsWith('multipart/form-data'));
      expect(sent.body, contains('name="file"'));
      expect(sent.body, contains('filename="photo.jpg"'));
    });

    for (final (status, code) in [
      (401, 'unauthorized'),
      (403, 'forbidden'),
      (422, 'rejected'),
      (429, 'rate-limited'),
      (500, 'http-500'),
    ]) {
      test('HTTP $status → $code', () async {
        await expectLater(
          client((_) async => http.Response(jsonEncode({'message': 'non'}), status))
              .uploadFile(photo),
          throwsA(isA<StockImgException>()
              .having((e) => e.code, 'code', code)
              .having((e) => e.message, 'message', 'non')),
        );
      });
    }

    test('erreur réseau → network', () async {
      await expectLater(
        client((_) async => throw http.ClientException('offline')).uploadFile(photo),
        throwsA(isA<StockImgException>().having((e) => e.code, 'code', 'network')),
      );
    });

    test('non configuré : aucune requête envoyée', () async {
      var called = false;
      final c = StockImgClient(
          baseUrl: '',
          apiKey: '',
          httpClient: MockClient((_) async {
            called = true;
            return http.Response('', 201);
          }));
      await expectLater(
        c.uploadFile(photo),
        throwsA(isA<StockImgException>().having((e) => e.code, 'code', 'not-configured')),
      );
      expect(called, isFalse);
    });
  });

  test('listFiles renvoie la liste', () async {
    final files = await client((req) async {
      expect(req.method, 'GET');
      expect(req.url.path, '/api/v1/files');
      return http.Response(
          jsonEncode({
            'data': [
              {'id': 2},
              {'id': 1}
            ]
          }),
          200);
    }).listFiles();
    expect(files.map((f) => f['id']), [2, 1]);
  });

  group('deleteFile', () {
    test('204 → succès', () async {
      await client((req) async {
        expect(req.method, 'DELETE');
        expect(req.url.path, '/api/v1/files/42');
        return http.Response('', 204);
      }).deleteFile(42);
    });

    test('403 → forbidden', () async {
      await expectLater(
        client((_) async => http.Response('', 403)).deleteFile(42),
        throwsA(isA<StockImgException>().having((e) => e.code, 'code', 'forbidden')),
      );
    });
  });
}
