import 'dart:math';
import 'dart:typed_data';

import 'package:ecolindk/services/waste_photo_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Grande photo "bruitée" (difficile à compresser), façon photo de 12 Mpx.
Uint8List noisyPhoto({int width = 4000, int height = 3000}) {
  final random = Random(7);
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    p
      ..r = random.nextInt(256)
      ..g = random.nextInt(256)
      ..b = random.nextInt(256);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  group('compressForFirestore', () {
    test('a large photo fits under the Firestore document limit', () {
      final original = noisyPhoto();
      expect(original.length, greaterThan(WastePhotoService.maxBytes));

      final jpeg = compressForFirestore(original);
      expect(jpeg.length, lessThanOrEqualTo(WastePhotoService.maxBytes));
      final decoded = img.decodeJpg(jpeg)!;
      expect(max(decoded.width, decoded.height), lessThanOrEqualTo(1280));
      // Proportions conservées (4:3).
      expect(decoded.width / decoded.height, closeTo(4 / 3, 0.01));
    });

    test('a small photo is not upscaled', () {
      final jpeg = compressForFirestore(noisyPhoto(width: 400, height: 300));
      final decoded = img.decodeJpg(jpeg)!;
      expect(decoded.width, 400);
      expect(decoded.height, 300);
    });

    test('a non-image file → invalid-image', () {
      expect(() => compressForFirestore(Uint8List.fromList([1, 2, 3, 4])),
          throwsA(isA<WastePhotoException>().having((e) => e.code, 'code', 'invalid-image')));
    });
  });

  test('upload stores the photo in Firestore and load reads it back', () async {
    final db = FakeFirebaseFirestore();
    final photos = WastePhotoService(firestore: db);

    final ref = await photos.uploadBytes('house', noisyPhoto(width: 800, height: 600));
    expect(WastePhotoService.isFirestoreRef(ref), isTrue);

    final id = ref.substring(WastePhotoService.refPrefix.length);
    final doc = (await db.collection('wastePhotos').doc(id).get()).data()!;
    expect(doc['ownerUid'], 'house');
    expect(doc['contentType'], 'image/jpeg');
    expect(doc['sizeBytes'], lessThanOrEqualTo(WastePhotoService.maxBytes));

    final bytes = await WastePhotoService(firestore: db).load(ref);
    expect(bytes, isNotNull);
    expect(img.decodeJpg(bytes!)!.width, 800);
    expect(WastePhotoService.isFirestoreRef('https://storage.example/a.jpg'), isFalse);
  });

  test('photo compressed once, then stored without recompression', () async {
    final db = FakeFirebaseFirestore();
    final jpeg = await WastePhotoService.compress(noisyPhoto(width: 2048, height: 1536));
    expect(jpeg.length, lessThanOrEqualTo(WastePhotoService.maxBytes));

    final ref = await WastePhotoService(firestore: db).uploadCompressed('house', jpeg);
    final id = ref.substring(WastePhotoService.refPrefix.length);
    final doc = (await db.collection('wastePhotos').doc(id).get()).data()!;
    expect(doc['sizeBytes'], jpeg.length); // exactement les octets préparés
  });

  test('already compressed but too heavy → too-large, nothing written', () async {
    final db = FakeFirebaseFirestore();
    await expectLater(
      WastePhotoService(firestore: db).uploadCompressed('house', Uint8List(WastePhotoService.maxBytes + 1)),
      throwsA(isA<WastePhotoException>().having((e) => e.code, 'code', 'too-large')),
    );
    expect((await db.collection('wastePhotos').get()).docs, isEmpty);
  });
}
