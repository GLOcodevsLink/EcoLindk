import 'package:ecolindk/services/gemini_service.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<GeminiServiceException>().having((e) => e.code, 'code', code));

/// Un appel reçu par le service Gemini de test.
class Call {
  final String model;
  final Content? system;
  final List<Content> contents;
  final GenerationConfig config;
  Call(this.model, this.system, this.contents, this.config);
}

String textOf(Content c) => c.parts.whereType<TextPart>().map((p) => p.text).join();

void main() {
  late List<Call> calls;

  GeminiService service(Future<String?> Function(Call call) reply, {List<String> models = const ['nouveau', 'secours']}) =>
      GeminiService(
        models: models,
        generate: ({required model, systemInstruction, required contents, required config}) {
          final call = Call(model, systemInstruction, contents, config);
          calls.add(call);
          return reply(call);
        },
      );

  setUp(() => calls = []);

  test('chat: EcoLindk instructions by role and language, full history', () async {
    final s = service((_) async => '  Bonjour !  ');
    final reply = await s.chat(
      history: const [
        GeminiChatTurn(fromUser: true, text: 'Salut'),
        GeminiChatTurn(fromUser: false, text: 'Bonjour'),
      ],
      message: 'Comment trier le verre ?',
      forCollector: true,
      french: false,
    );

    expect(reply, 'Bonjour !');
    final call = calls.single;
    expect(call.model, 'nouveau');
    expect(textOf(call.system!), contains('COLLECTOR'));
    expect(textOf(call.system!), contains('Reply in English'));
    expect(call.contents.map((c) => c.role), ['user', 'model', 'user']);
    expect(textOf(call.contents.last), 'Comment trier le verre ?');
  });

  test('primary model overloaded → answer from the fallback model', () async {
    final s = service((call) async {
      if (call.model == 'nouveau') throw ServerException('The model is overloaded');
      return 'Salut';
    });
    expect(await s.chat(history: const [], message: 'x', forCollector: false, french: true), 'Salut');
    expect(calls.map((c) => c.model), ['nouveau', 'secours']);
  });

  test('primary model available → the fallback is never called', () async {
    final s = service((_) async => 'Salut');
    await s.chat(history: const [], message: 'x', forCollector: false, french: true);
    expect(calls.map((c) => c.model), ['nouveau']);
  });

  test('AI not enabled in Firebase → not-configured, fallback not tried', () async {
    final s = service((_) async => throw ServiceApiNotEnabled('AI Logic API disabled'));
    await expectLater(
        s.chat(history: const [], message: 'x', forCollector: false, french: true), throwsCode('not-configured'));
    expect(calls, hasLength(1));
  });

  test('quota exceeded on both models → rate-limited', () async {
    final s = service((_) async => throw QuotaExceeded('quota'));
    await expectLater(
        s.chat(history: const [], message: 'x', forCollector: false, french: true), throwsCode('rate-limited'));
    expect(calls, hasLength(2));
  });

  test('empty answer → invalid-response', () async {
    final s = service((_) async => '  ', models: const ['nouveau']);
    await expectLater(
        s.chat(history: const [], message: 'x', forCollector: false, french: true), throwsCode('invalid-response'));
  });

  test('classifyWasteImage sends instructions + image and decodes the JSON', () async {
    final s = service((_) async => '{"category":"glass","confidence":0.8,"estimatedWeightKg":2}');
    final json = await s.classifyWasteImage(imageBytes: [1, 2, 3], mimeType: 'image/png');

    expect(json['category'], 'glass');
    final parts = calls.single.contents.single.parts;
    expect((parts[0] as TextPart).text, contains('waste-identification'));
    final image = parts[1] as InlineDataPart;
    expect(image.mimeType, 'image/png');
    expect(image.bytes, [1, 2, 3]);
    expect(calls.single.config.responseMimeType, 'application/json');
  });

  test('classifyWasteImage: non-JSON text → invalid-response', () async {
    final s = service((_) async => 'pas du json');
    await expectLater(s.classifyWasteImage(imageBytes: [1], mimeType: 'image/jpeg'), throwsCode('invalid-response'));
  });
}
