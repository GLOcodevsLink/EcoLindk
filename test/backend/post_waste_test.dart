import 'dart:convert';
import 'dart:typed_data';

import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/models/collection_zone.dart';
import 'package:ecolindk/services/ai_classifier.dart';
import 'package:ecolindk/services/collection_service.dart';
import 'package:ecolindk/services/collector_zone_service.dart';
import 'package:ecolindk/services/gemini_service.dart';
import 'package:ecolindk/services/geocoding_service.dart';
import 'package:ecolindk/services/waste_photo_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

// Quartiers de Yaoundé (coordonnées approximatives).
const bastos = (3.8950, 11.5100);
const nkolbisson = (3.8700, 11.4400);

/// Photo de test (dégradé), au format JPEG.
Uint8List samplePhoto({int width = 1600, int height = 1200}) {
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    p
      ..r = (p.x * 255 ~/ width)
      ..g = (p.y * 255 ~/ height)
      ..b = 120;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// Service IA de test : renvoie toujours [json] (réponse de Gemini).
GeminiService aiReturning(Map<String, dynamic> json) => GeminiService(
      models: const ['test-model'],
      generate: ({required model, systemInstruction, required contents, required config}) async => jsonEncode(json),
    );

void main() {
  late FakeFirebaseFirestore db;
  late CollectionService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    // Géocodage inverse de test : tout point de Yaoundé est situé à Bastos.
    service = CollectionService(
      firestore: db,
      geocoding: GeocodingService(client: MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'address': {'suburb': 'Bastos', 'city': 'Yaoundé'}
          })),
          200))),
    );
    // Un collecteur dont la zone est Bastos.
    await db.collection('users').doc('collector').set({'role': 'collector'});
    await CollectorZoneService(firestore: db).save('collector', const [
      CollectionZone(
          country: 'Cameroon', countryCode: 'CM', city: 'Yaoundé', neighborhood: 'Bastos', latitude: 3.8950, longitude: 11.5100),
    ]);
  });

  Future<CollectionRequest> publish({
    required WasteCategory category,
    required String quantity,
    required (double, double) at,
    String? aiDecision,
    WasteCategory? aiCategory,
    String? neighborhood,
    String? city,
    String imageUrl = 'firestore://wastePhotos/photo1',
  }) =>
      service.createRequest(
        householdUid: 'supplier',
        householdName: 'Awa',
        imageUrl: imageUrl,
        description: 'Plastic bottles, clean and crushed',
        category: category,
        quantityRange: quantity,
        aiRequested: true,
        aiSuggestedCategory: aiCategory,
        aiConfidence: aiCategory == null ? null : 0.92,
        aiDecision: aiDecision,
        address: neighborhood == null ? 'Current location (GPS)' : '$neighborhood, $city',
        latitude: at.$1,
        longitude: at.$2,
        locationIsApproximate: neighborhood != null,
        neighborhood: neighborhood,
        city: city,
      );

  Future<List<Map<String, dynamic>>> notificationsOf(String uid) async =>
      (await db.collection('notifications').doc(uid).collection('items').get()).docs.map((d) => d.data()).toList();

  group('Photo', () {
    test('the photo is compressed under 1 MB and stored in Firestore', () async {
      final jpeg = await WastePhotoService.compress(samplePhoto(width: 4000, height: 3000));
      expect(jpeg.length, lessThanOrEqualTo(WastePhotoService.maxBytes));

      final ref = await WastePhotoService(firestore: db).uploadCompressed('supplier', jpeg);
      expect(ref, startsWith(WastePhotoService.refPrefix));
      final stored = await WastePhotoService(firestore: db).load(ref);
      expect(stored, isNotNull);
    });

    test('a file that is not an image is rejected', () async {
      await expectLater(WastePhotoService.compress(Uint8List.fromList([1, 2, 3, 4])),
          throwsA(isA<WastePhotoException>().having((e) => e.code, 'code', 'invalid-image')));
    });
  });

  group('AI analysis', () {
    test('the AI identifies the category and estimates the weight', () async {
      final result = await AiClassifier.classifyBytes(samplePhoto(), 'image/jpeg',
          gemini: aiReturning({'category': 'plastic', 'confidence': 0.92, 'estimatedWeightKg': 6}));
      expect(result.category, WasteCategory.plastic);
      expect(result.confidence, 0.92);
      expect(result.estimatedWeightKg, 6);
    });

    test('a photo with no recyclable waste is reported as unsupported', () async {
      await expectLater(
        AiClassifier.classifyBytes(samplePhoto(), 'image/jpeg',
            gemini: aiReturning({'category': 'unsupported', 'confidence': 0.9, 'estimatedWeightKg': null})),
        throwsA(isA<AiClassificationException>().having((e) => e.code, 'code', 'unsupported')),
      );
    });

    test('AI result accepted: the AI values become the post data', () async {
      final ai = await AiClassifier.classifyBytes(samplePhoto(), 'image/jpeg',
          gemini: aiReturning({'category': 'metal', 'confidence': 0.88, 'estimatedWeightKg': 4}));
      final post = await publish(
          category: ai.category, quantity: '${ai.estimatedWeightKg!.toInt()} kg', at: bastos,
          aiDecision: 'accepted', aiCategory: ai.category);

      expect(post.category, WasteCategory.metal);
      expect(post.quantityRange, '4 kg');
      expect(post.aiDecision, 'accepted');
    });

    test('AI result rejected: the values corrected by the supplier are saved', () async {
      final post = await publish(
          category: WasteCategory.glass, quantity: '7 kg', at: bastos,
          aiDecision: 'refused', aiCategory: WasteCategory.plastic);

      expect(post.category, WasteCategory.glass); // correction du fournisseur
      expect(post.quantityRange, '7 kg');
      expect(post.aiSuggestedCategory, WasteCategory.plastic); // proposition de l'IA gardée
      expect(post.aiDecision, 'refused');
    });
  });

  group('Publishing', () {
    test('the post is created as pending with its photo and location', () async {
      final post = await publish(category: WasteCategory.plastic, quantity: '6 kg', at: bastos);

      expect(post.status, RequestStatus.pending);
      expect(post.householdUid, 'supplier');
      expect(post.imageUrl, 'firestore://wastePhotos/photo1');
      expect(post.latitude, bastos.$1);
      expect(post.longitude, bastos.$2);
      expect(post.collectorUid, isNull);
    });

    test('GPS location: the neighborhood is found automatically', () async {
      final post = await publish(category: WasteCategory.plastic, quantity: '6 kg', at: bastos);
      expect(post.neighborhood, 'Bastos');
      expect(post.city, 'Yaoundé');
      expect(post.locationIsApproximate, isFalse);
    });

    test('address picked from the list: that city and neighborhood are saved', () async {
      final post = await publish(
          category: WasteCategory.paperCardboard, quantity: '3 kg', at: bastos,
          neighborhood: 'Bastos Golf', city: 'Yaoundé');
      expect(post.neighborhood, 'Bastos Golf');
      expect(post.address, 'Bastos Golf, Yaoundé');
      expect(post.locationIsApproximate, isTrue);
    });

    test('the supplier receives a confirmation notification', () async {
      final post = await publish(category: WasteCategory.plastic, quantity: '6 kg', at: bastos);
      final notifs = await notificationsOf('supplier');
      expect(notifs.single['type'], 'requestSubmitted');
      expect(notifs.single['relatedRequestId'], post.id);
    });

    test('a collector whose zone is nearby is notified once', () async {
      final post = await publish(category: WasteCategory.plastic, quantity: '6 kg', at: bastos);
      final notifs = await notificationsOf('collector');
      expect(notifs, hasLength(1));
      expect(notifs.single['title'], 'Nouveau post disponible');
      expect(notifs.single['relatedRequestId'], post.id);
    });

    test('a collector whose zones are far away is not notified', () async {
      await db.collection('users').doc('far').set({'role': 'collector'});
      await CollectorZoneService(firestore: db).save('far', const [
        CollectionZone(
            country: 'Cameroon', countryCode: 'CM', city: 'Douala', neighborhood: 'Akwa', latitude: 4.05, longitude: 9.70),
      ]);
      await publish(category: WasteCategory.plastic, quantity: '6 kg', at: nkolbisson,
          neighborhood: 'Nkolbisson', city: 'Yaoundé');
      expect(await notificationsOf('far'), isEmpty);
    });

    test('the post appears in the list of available pickups', () async {
      final post = await publish(category: WasteCategory.plastic, quantity: '6 kg', at: bastos);
      final available = await service.watchAvailableRequests().first;
      expect(available.map((r) => r.id), contains(post.id));
    });

    test('the supplier can cancel a post that nobody has accepted yet', () async {
      final post = await publish(category: WasteCategory.plastic, quantity: '6 kg', at: bastos);
      await service.cancelRequest(post.id);
      final updated = await service.watchRequest(post.id).first;
      expect(updated!.status, RequestStatus.cancelled);
      expect((await service.watchAvailableRequests().first).map((r) => r.id), isNot(contains(post.id)));
    });
  });
}
