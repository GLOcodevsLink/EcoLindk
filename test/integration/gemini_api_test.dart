// Real calls to the Gemini API with the key from .env. Skipped unless set:
//   GEMINI_API_KEY=$(grep ^GEMINI_API_KEY= .env | cut -d= -f2-) flutter test test/integration
import 'dart:io';
import 'package:ecolindk/services/ai_model_settings.dart';
import 'package:ecolindk/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  final String key = Platform.environment['GEMINI_API_KEY'] ?? '';
  final String? skip = key.isEmpty ? 'GEMINI_API_KEY not set' : null;

  GeminiService service() => GeminiService(
        models: [AiModelSettings.defaultModel, AiModelSettings.defaultFallbackModel],
        generate: ({required model, systemInstruction, required contents, required config}) =>
            GeminiService.restGenerate(
              client: http.Client(),
              apiKey: key,
              model: model,
              systemInstruction: systemInstruction,
              contents: contents,
              config: config,
            ),
      );

  test('assistant answers a recycling question', () async {
    final String answer = await service().chat(
      history: const [],
      message: 'Comment trier une bouteille en plastique ?',
      forCollector: false,
      french: true,
    );
    // ignore: avoid_print
    print('Assistant: ${answer.length > 200 ? '${answer.substring(0, 200)}…' : answer}');
    expect(answer, isNotEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('classifier returns the expected JSON for a photo', () async {
    final List<int> bytes = File('assets/images/howitworks_post.png').readAsBytesSync();
    final Map<String, dynamic> json =
        await service().classifyWasteImage(imageBytes: bytes, mimeType: 'image/png');
    // ignore: avoid_print
    print('Classifier: $json');
    expect(json.keys, containsAll(<String>['category', 'confidence']));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
