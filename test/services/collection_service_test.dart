import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/services/collection_service.dart';
import 'package:ecolindk/services/stockimg_client.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CollectionService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = CollectionService(
      firestore: db,
      stockImg: StockImgClient(baseUrl: 'https://img.test', apiKey: 'k'),
    );
  });

  Future<List<Map<String, dynamic>>> notificationsOf(String uid) async =>
      (await db.collection('notifications').doc(uid).collection('items').get())
          .docs
          .map((d) => d.data())
          .toList();

  Future<CollectionRequest> post({String quantity = '5 kg'}) => service.createRequest(
        householdUid: 'house',
        householdName: 'Awa',
        imageUrl: 'https://img.test/a.jpg',
        description: 'Bouteilles',
        category: WasteCategory.plastic,
        quantityRange: quantity,
        aiRequested: false,
        address: 'Akwa, Douala',
        latitude: 4.0511,
        longitude: 9.7679,
        locationIsApproximate: false,
      );

  Future<CollectionRequest> reload(String id) async =>
      CollectionRequest.fromDoc(await db.collection('collectionRequests').doc(id).get());

  group('createRequest', () {
    test('crée une demande pending et notifie le fournisseur', () async {
      final r = await post();
      expect(r.status, RequestStatus.pending);
      expect(r.imageUrl, 'https://img.test/a.jpg');
      final notifs = await notificationsOf('house');
      expect(notifs.single['type'], 'requestSubmitted');
      expect(notifs.single['relatedRequestId'], r.id);
    });

    test('ne notifie que les collecteurs à moins de 10 km', () async {
      await service.setCollectorLocation('proche', 4.06, 9.77); // ~1 km
      await service.setCollectorLocation('loin', 3.848, 11.502); // Yaoundé
      await post();
      expect((await notificationsOf('proche')).single['type'], 'newNearbyPost');
      expect(await notificationsOf('loin'), isEmpty);
    });
  });

  test('setCollectorLocation / getCollectorLocation', () async {
    expect(await service.getCollectorLocation('c1'), isNull);
    await service.setCollectorLocation('c1', 4.0, 9.7);
    final p = await service.getCollectorLocation('c1');
    expect(p!.latitude, 4.0);
    expect(p.longitude, 9.7);
  });

  group('acceptRequest', () {
    test('assigne le collecteur et notifie le fournisseur', () async {
      final r = await post();
      await service.acceptRequest(r.id, collectorUid: 'c1', collectorName: 'Paul');
      final updated = await reload(r.id);
      expect(updated.status, RequestStatus.accepted);
      expect(updated.collectorUid, 'c1');
      expect((await notificationsOf('house')).map((n) => n['type']), contains('requestAccepted'));
    });

    test('une demande ne peut être acceptée que par un seul collecteur', () async {
      final r = await post();
      await service.acceptRequest(r.id, collectorUid: 'c1', collectorName: 'Paul');
      await expectLater(service.acceptRequest(r.id, collectorUid: 'c2', collectorName: 'Marie'),
          throwsStateError);
      expect((await reload(r.id)).collectorUid, 'c1');
    });

    test('une demande annulée ne peut pas être acceptée', () async {
      final r = await post();
      await service.cancelRequest(r.id);
      await expectLater(
          service.acceptRequest(r.id, collectorUid: 'c1', collectorName: 'Paul'), throwsStateError);
    });
  });

  group('résultat de collecte', () {
    late String id;

    setUp(() async {
      id = (await post(quantity: '5 kg')).id; // bornes : 3 à 7 kg
      await service.acceptRequest(id, collectorUid: 'c1', collectorName: 'Paul');
    });

    test('poids hors de la fourchette déclarée → refusé', () async {
      await expectLater(
          service.submitCollectionResult(id, weightKg: 10, priceFcfa: 500), throwsFormatException);
      await expectLater(
          service.submitCollectionResult(id, weightKg: 1, priceFcfa: 500), throwsFormatException);
      expect((await reload(id)).status, RequestStatus.accepted);
    });

    test('soumission → inProgress, puis confirmation → completed avec points', () async {
      await service.submitCollectionResult(id, weightKg: 4, priceFcfa: 300);
      var r = await reload(id);
      expect(r.status, RequestStatus.inProgress);
      expect(r.pendingWeightKg, 4);
      expect(r.pendingPriceFcfa, 300);

      await service.confirmCollectionResult(id);
      r = await reload(id);
      expect(r.status, RequestStatus.completed);
      expect(r.weightKg, 4);
      expect(r.valueFcfa, 300);
      expect(r.pointsEarned, 40); // plastique : 10 pts/kg × 4 kg
      expect(r.pendingWeightKg, isNull);
      expect((await notificationsOf('c1')).map((n) => n['type']), contains('requestCompleted'));
    });

    test('refus → retour à accepted et le collecteur est prévenu', () async {
      await service.submitCollectionResult(id, weightKg: 4, priceFcfa: 300);
      await service.rejectCollectionResult(id);
      final r = await reload(id);
      expect(r.status, RequestStatus.accepted);
      expect(r.pendingWeightKg, isNull);
      expect((await notificationsOf('c1')).map((n) => n['type']), contains('collectionRejected'));
    });

    test('confirmer sans soumission préalable ne fait rien', () async {
      await service.confirmCollectionResult(id);
      expect((await reload(id)).status, RequestStatus.accepted);
    });
  });

  test('settleCompletedRequest crédite les points une seule fois', () async {
    final id = (await post()).id;
    await service.acceptRequest(id, collectorUid: 'c1', collectorName: 'Paul');
    await service.submitCollectionResult(id, weightKg: 5, priceFcfa: 375);
    await service.confirmCollectionResult(id);
    final done = await reload(id);

    await settleCompletedRequest(done, firestore: db);
    await settleCompletedRequest(done, firestore: db);

    final wallet = await db.collection('wallets').doc('house').get();
    expect(wallet.data()!['pointsBalance'], 50);
  });
}
