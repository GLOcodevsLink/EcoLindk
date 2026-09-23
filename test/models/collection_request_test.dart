import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // FieldValue.serverTimestamp() doit être créé APRÈS l'installation de la
  // fausse plateforme Firestore, sinon fake_cloud_firestore ne le reconnaît pas.
  setUpAll(FakeFirebaseFirestore.new);

  group('weightBoundsKg', () {
    test('anciens paliers reconnus tels quels', () async {
      expect('< 1 kg'.weightBoundsKg, (0, 1));
      expect('1 - 5 kg'.weightBoundsKg, (1, 5));
      expect('5 - 10 kg'.weightBoundsKg, (5, 10));
      expect('10+ kg'.weightBoundsKg, (10, double.infinity));
    });

    test('quantité libre : tolérance de ±40 %', () async {
      final (min, max) = '10 kg'.weightBoundsKg;
      expect(min, closeTo(6, 1e-9));
      expect(max, closeTo(14, 1e-9));
    });

    test('accepte la virgule décimale', () async {
      final (min, max) = '2,5 kg'.weightBoundsKg;
      expect(min, closeTo(1.5, 1e-9));
      expect(max, closeTo(3.5, 1e-9));
    });

    test('texte illisible ou zéro : aucune borne', () async {
      expect('beaucoup'.weightBoundsKg, (0, double.infinity));
      expect('0 kg'.weightBoundsKg, (0, double.infinity));
      expect(''.weightBoundsKg, (0, double.infinity));
    });
  });

  group('enums', () {
    test('fromName retombe sur une valeur par défaut', () async {
      expect(WasteCategoryX.fromName('glass'), WasteCategory.glass);
      expect(WasteCategoryX.fromName('inconnu'), WasteCategory.plastic);
      expect(WasteCategoryX.fromName(null), WasteCategory.plastic);
      expect(RequestStatusX.fromName('completed'), RequestStatus.completed);
      expect(RequestStatusX.fromName(null), RequestStatus.pending);
    });

    test('libellés FR/EN non vides', () async {
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

    test('reference : 6 premiers caractères en majuscules', () async {
      expect(build('abcdef123').reference, 'ECL-ABCDEF');
      expect(build('ab').reference, 'ECL-AB');
    });

    test('toCreateMap force le statut pending sans collecteur', () async {
      final map = build('x').toCreateMap();
      expect(map['status'], 'pending');
      expect(map['collectorUid'], isNull);
      expect(map['category'], 'glass');
      expect(map['aiSuggestedCategory'], 'glass');
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('aller-retour Firestore via fromDoc', () async {
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

    test('fromDoc tolère un document incomplet', () async {
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
