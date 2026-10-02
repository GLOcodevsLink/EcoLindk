import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ecolindk/core/rewards_config.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/services/ai_classifier.dart';
import 'package:ecolindk/services/gemini_service.dart';
import 'package:ecolindk/services/waste_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Tests unitaires du module "Poster un déchet" : chaque test vérifie une
/// seule classe ou fonction, sans base de données ni réseau.

Uint8List photo(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    p
      ..r = (p.x * 255 ~/ width)
      ..g = (p.y * 255 ~/ height)
      ..b = 90;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// Service IA de test : renvoie toujours [json] (réponse de Gemini).
GeminiService aiReturning(Map<String, dynamic> json) => GeminiService(
      models: const ['test-model'],
      generate: ({required model, systemInstruction, required contents, required config}) async => jsonEncode(json),
    );

Future<AiClassificationResult> classify(Map<String, dynamic> json) =>
    AiClassifier.classifyBytes(photo(64, 48), 'image/jpeg', gemini: aiReturning(json));

Matcher throwsAiError(String code) =>
    throwsA(isA<AiClassificationException>().having((e) => e.code, 'code', code));

void main() {
  group('Photo compression', () {
    test('a large photo is reduced under 1 MB', () {
      final jpeg = compressForFirestore(photo(4000, 3000));
      expect(jpeg.length, lessThanOrEqualTo(WastePhotoService.maxBytes));
    });

    test('the longest side is reduced to 1280 pixels, proportions kept', () {
      final out = img.decodeJpg(compressForFirestore(photo(4000, 3000)))!;
      expect(math.max(out.width, out.height), 1280);
      expect(out.width / out.height, closeTo(4 / 3, 0.01));
    });

    test('a small photo is not enlarged', () {
      final out = img.decodeJpg(compressForFirestore(photo(400, 300)))!;
      expect(out.width, 400);
      expect(out.height, 300);
    });

    test('a file that is not an image is rejected', () {
      expect(() => compressForFirestore(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<WastePhotoException>().having((e) => e.code, 'code', 'invalid-image')));
    });
  });

  group('AI analysis result', () {
    test('reads the category, confidence and estimated weight', () async {
      final r = await classify({'category': 'plastic', 'confidence': 0.92, 'estimatedWeightKg': 6});
      expect(r.category, WasteCategory.plastic);
      expect(r.confidence, 0.92);
      expect(r.estimatedWeightKg, 6);
    });

    test('the AI can recognize beverage cans', () async {
      final r = await classify({'category': 'beverageCans', 'confidence': 0.9, 'estimatedWeightKg': 1.5});
      expect(r.category, WasteCategory.beverageCans);
    });

    test('a photo without recyclable waste is reported as unsupported', () async {
      await expectLater(classify({'category': 'unsupported', 'confidence': 0.9}), throwsAiError('unsupported'));
    });

    test('a category outside the app categories is refused', () async {
      await expectLater(classify({'category': 'wood', 'confidence': 0.9}), throwsAiError('unsupported'));
    });

    test('a missing or invalid weight is left empty for the user to fill', () async {
      final r = await classify({'category': 'glass', 'confidence': 0.8, 'estimatedWeightKg': 0});
      expect(r.estimatedWeightKg, isNull);
    });

    test('the confidence is always between 0 and 1', () async {
      final r = await classify({'category': 'metal', 'confidence': 1.7, 'estimatedWeightKg': 2});
      expect(r.confidence, 1.0);
    });

    test('an empty image is refused before any analysis', () async {
      await expectLater(
          AiClassifier.classifyBytes(const [], 'image/jpeg', gemini: aiReturning({'category': 'plastic'})),
          throwsAiError('invalid-image'));
    });
  });

  group('Waste categories', () {
    test('beverage cans are a category of their own, separate from metal', () {
      expect(WasteCategory.values, contains(WasteCategory.beverageCans));
      expect(WasteCategory.beverageCans.label(false), 'Beverage cans');
      expect(WasteCategory.metal.label(false), 'Metal');
      expect(WasteCategoryX.fromName('beverageCans'), WasteCategory.beverageCans);
    });

    test('the app offers 5 categories, each with a label and examples', () {
      expect(WasteCategory.values, hasLength(5));
      for (final c in WasteCategory.values) {
        expect(c.label(false), isNotEmpty);
        expect(c.examples(false), isNotEmpty);
      }
    });

    test('an unknown category name falls back to plastic', () {
      expect(WasteCategoryX.fromName('glass'), WasteCategory.glass);
      expect(WasteCategoryX.fromName('unknown'), WasteCategory.plastic);
      expect(WasteCategoryX.tryFromName('unknown'), isNull);
    });
  });

  group('Estimated points shown before posting', () {
    test('points = rate of the category × weight', () {
      expect(RewardsConfig.pointsForCollection(WasteCategory.plastic, 6), 18); // 3 P/kg
      expect(RewardsConfig.pointsForCollection(WasteCategory.metal, 2), 12); // 6 P/kg
      expect(RewardsConfig.pointsForCollection(WasteCategory.glass, 4), 2); // 0.5 P/kg
    });

    test('every category has a points rate', () {
      for (final c in WasteCategory.values) {
        expect(RewardsConfig.pointsPerKg[c], isNotNull);
      }
    });
  });
}
