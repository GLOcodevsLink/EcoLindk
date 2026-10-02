import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // FieldValue.serverTimestamp() doit être créé APRÈS l'installation de la
  // plateforme Firestore de test, sinon il n'est pas reconnu.
  setUpAll(FakeFirebaseFirestore.new);

  group('weightBoundsKg', () {
    test('legacy ranges are recognized as-is', () async {
      expect('< 1 kg'.weightBoundsKg, (0, 1));
      expect('1 - 5 kg'.weightBoundsKg, (1, 5));
      expect('5 - 10 kg'.weightBoundsKg, (5, 10));
      expect('10+ kg'.weightBoundsKg, (10, double.infinity));
    });

    test('free quantity: ±5 kg tolerance', () async {
      final (min, max) = '15 kg'.weightBoundsKg;
      expect(min, closeTo(10, 1e-9));
      expect(max, closeTo(20, 1e-9));
    });

    test('accepts a decimal comma, lower bound never negative', () async {
      final (min, max) = '2,5 kg'.weightBoundsKg;
      expect(min, 0);
      expect(max, closeTo(7.5, 1e-9));
    });
  });

  group('acceptsCollectedWeight', () {
    test('rejects a gap over 5 kg, accepts exactly 5 kg', () async {
      expect('15 kg'.acceptsCollectedWeight(15), isTrue);
      expect('15 kg'.acceptsCollectedWeight(20), isTrue);
      expect('15 kg'.acceptsCollectedWeight(10), isTrue);
      expect('6 kg'.acceptsCollectedWeight(11), isTrue);
      expect('6.2 kg'.acceptsCollectedWeight(1.2), isTrue);
      expect('15 kg'.acceptsCollectedWeight(20.1), isFalse);
      expect('15 kg'.acceptsCollectedWeight(9.9), isFalse);
      expect('15 kg'.acceptsCollectedWeight(40), isFalse);
    });

    test('rejects zero or negative weight', () async {
      expect('3 kg'.acceptsCollectedWeight(0), isFalse);
      expect('3 kg'.acceptsCollectedWeight(-1), isFalse);
    });

    test('legacy ranges: inclusive bounds', () async {
      expect('1 - 5 kg'.acceptsCollectedWeight(5), isTrue);
      expect('1 - 5 kg'.acceptsCollectedWeight(6), isFalse);
    });

    test('unreadable text or zero: no bounds', () async {
      expect('beaucoup'.weightBoundsKg, (0, double.infinity));
      expect('0 kg'.weightBoundsKg, (0, double.infinity));
      expect(''.weightBoundsKg, (0, double.infinity));
    });
  });

  group('enums', () {
    test('fromName falls back to a default value', () async {
      expect(WasteCategoryX.fromName('glass'), WasteCategory.glass);
      expect(WasteCategoryX.fromName('inconnu'), WasteCategory.plastic);
      expect(WasteCategoryX.fromName(null), WasteCategory.plastic);
      expect(RequestStatusX.fromName('completed'), RequestStatus.completed);
      expect(RequestStatusX.fromName(null), RequestStatus.pending);
    });

    test('FR/EN labels are not empty', () async {
      for (final c in WasteCategory.values) {
        expect(c.label(true), isNotEmpty);
        expect(c.label(false), isNotEmpty);
      }
      for (final s in RequestStatus.values) {
        expect(s.label(true), isNotEmpty);
        expect(s.label(false), isNotEmpty);
      }
    });
  });

  group('CollectionRequest', () {
    CollectionRequest build(String id) => CollectionRequest(
          id: id,
          householdUid: 'h1',
          householdName: 'Awa',
          imageUrl: 'https://img/x.jpg',
          description: 'Bouteilles',
          category: WasteCategory.glass,
          quantityRange: '3 kg',
          aiRequested: true,
          aiSuggestedCategory: WasteCategory.glass,
          aiConfidence: 0.9,
          address: 'Akwa, Douala',
          latitude: 4.05,
          longitude: 9.7,
          locationIsApproximate: false,
          status: RequestStatus.accepted,
          createdAt: DateTime(2026),
        );

    test('reference: first 6 characters in uppercase', () async {
      expect(build('abcdef123').reference, 'ECL-ABCDEF');
      expect(build('ab').reference, 'ECL-AB');
    });

    test('toCreateMap forces pending status with no collector', () async {
      final map = build('x').toCreateMap();
      expect(map['status'], 'pending');
      expect(map['collectorUid'], isNull);
      expect(map['category'], 'glass');
      expect(map['aiSuggestedCategory'], 'glass');
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('Firestore round trip via fromDoc', () async {
      final db = FakeFirebaseFirestore();
      final ref = await db.collection('collectionRequests').add(build('').toCreateMap());
      final r = CollectionRequest.fromDoc(await ref.get());

      expect(r.id, ref.id);
      expect(r.householdUid, 'h1');
      expect(r.category, WasteCategory.glass);
      expect(r.aiConfidence, 0.9);
      expect(r.status, RequestStatus.pending);
      expect(r.locationIsApproximate, isFalse);
      expect(r.collectorUid, isNull);
    });

    test('fromDoc tolerates an incomplete document', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('c').doc('d').set({'latitude': 3});
      final r = CollectionRequest.fromDoc(await db.collection('c').doc('d').get());
      expect(r.latitude, 3.0);
      expect(r.category, WasteCategory.plastic);
      expect(r.status, RequestStatus.pending);
      expect(r.locationIsApproximate, isTrue);
      expect(r.aiSuggestedCategory, isNull);
    });
  });
}
