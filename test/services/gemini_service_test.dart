import 'dart:convert';

import 'package:ecolindk/services/gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response geminiReply(String text) => http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    }),
    200);

Matcher throwsCode(String code) =>
    throwsA(isA<GeminiServiceException>().having((e) => e.code, 'code', code));

void main() {
  group('sans clé API', () {
    setUp(() => dotenv.loadFromString(envString: 'GEMINI_API_KEY=YOUR_GEMINI_API_KEY_HERE'));

    test('aucune requête envoyée → no-api-key', () {
      final s = GeminiService(client: MockClient((_) async => fail('ne doit pas appeler')));
      expect(s.chat(history: const [], message: 'hi', systemInstruction: ''),
          throwsCode('no-api-key'));
    });
  });

  group('avec clé API', () {
    setUp(() => dotenv.loadFromString(envString: 'GEMINI_API_KEY=cle-test'));

    test('chat envoie historique + message et renvoie le texte', () async {
      late Map<String, dynamic> body;
      late Uri url;
      final s = GeminiService(client: MockClient((req) async {
        url = req.url;
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return geminiReply('  Bonjour !  ');
      }));

      final reply = await s.chat(
        history: const [GeminiChatTurn(fromUser: true, text: 'Salut'),
          GeminiChatTurn(fromUser: false, text: 'Bonjour')],
        message: 'Comment trier le verre ?',
        systemInstruction: 'Tu es EcoLindk.',
      );

      expect(reply, 'Bonjour !');
      expect(url.queryParameters['key'], 'cle-test');
      final contents = body['contents'] as List;
      expect(contents.map((c) => c['role']), ['user', 'model', 'user']);
      expect(contents.last['parts'][0]['text'], 'Comment trier le verre ?');
      expect(body['systemInstruction']['parts'][0]['text'], 'Tu es EcoLindk.');
    });

    test('réponse vide → invalid-response', () {
      final s = GeminiService(client: MockClient((_) async => geminiReply('  ')));
      expect(s.chat(history: const [], message: 'x', systemInstruction: ''),
          throwsCode('invalid-response'));
    });

    test('HTTP ≠ 200 → http-error', () {
      final s = GeminiService(client: MockClient((_) async => http.Response('', 429)));
      expect(s.chat(history: const [], message: 'x', systemInstruction: ''),
          throwsCode('http-error'));
    });

    test('pas de réseau → network', () {
      final s = GeminiService(
          client: MockClient((_) async => throw http.ClientException('offline')));
      expect(s.chat(history: const [], message: 'x', systemInstruction: ''),
          throwsCode('network'));
    });

    test('classifyWasteImage envoie l\'image en base64 et décode le JSON', () async {
      late Map<String, dynamic> body;
      final s = GeminiService(client: MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return geminiReply('{"category":"glass","confidence":0.8,"estimatedWeightKg":2}');
      }));

      final json = await s.classifyWasteImage(
          imageBytes: [1, 2, 3], mimeType: 'image/png', prompt: 'Classe');

      expect(json['category'], 'glass');
      final parts = body['contents'][0]['parts'] as List;
      expect(parts[1]['inline_data']['mime_type'], 'image/png');
      expect(parts[1]['inline_data']['data'], base64Encode([1, 2, 3]));
      expect(body['generationConfig']['responseMimeType'], 'application/json');
    });

    test('classifyWasteImage : texte non JSON → invalid-response', () {
      final s = GeminiService(client: MockClient((_) async => geminiReply('pas du json')));
      expect(s.classifyWasteImage(imageBytes: [1], mimeType: 'image/jpeg', prompt: ''),
          throwsCode('invalid-response'));
    });
  });
}
