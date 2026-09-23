import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/models/wallet_models.dart';
import 'package:ecolindk/services/wallet_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late WalletService wallet;

  setUp(() {
    db = FakeFirebaseFirestore();
    wallet = WalletService(firestore: db);
  });

  CollectionRequest completed({int? points = 40, RequestStatus status = RequestStatus.completed}) =>
      CollectionRequest(
        id: 'req123456',
        householdUid: 'house',
        householdName: 'Awa',
        imageUrl: '',
        description: '',
        category: WasteCategory.plastic,
        quantityRange: '4 kg',
        aiRequested: false,
        address: '',
        latitude: 0,
        longitude: 0,
        locationIsApproximate: false,
        status: status,
        pointsEarned: points,
        weightKg: 4,
        createdAt: DateTime(2026),
      );

  test('solde à 0 pour un nouveau portefeuille', () async {
    expect(await wallet.watchBalance('nouveau').first, 0);
  });

  test('creditPoints augmente solde et total gagné, et journalise', () async {
    await wallet.creditPoints(uid: 'u', points: 30, label: 'Bonus');
    await wallet.creditPoints(uid: 'u', points: 20, label: 'Bonus');
    expect(await wallet.watchBalance('u').first, 50);
    expect(await wallet.watchLifetimeEarned('u').first, 50);
    expect((await wallet.watchTransactions('u').first).length, 2);
  });

  group('claimCollectionPoints', () {
    test('crédite une fois, même appelé plusieurs fois', () async {
      await wallet.claimCollectionPoints(completed());
      await wallet.claimCollectionPoints(completed());
      expect(await wallet.watchBalance('house').first, 40);
      final notifs =
          await db.collection('notifications').doc('house').collection('items').get();
      expect(notifs.docs.single.data()['type'], 'pointsCredited');
    });

    test('ignore une demande non terminée ou sans points', () async {
      await wallet.claimCollectionPoints(completed(status: RequestStatus.inProgress));
      await wallet.claimCollectionPoints(completed(points: null));
      expect(await wallet.watchBalance('house').first, 0);
    });
  });

  group('redeem (conversion simulée)', () {
    test('débite le solde et enregistre la conversion', () async {
      await wallet.creditPoints(uid: 'u', points: 30, label: 'Bonus');
      final r = await wallet.redeem(
          uid: 'u', method: RedemptionMethod.airtime, points: 15, recipientPhone: '+237650000000');

      expect(r.status, RedemptionStatus.completed);
      expect(await wallet.watchBalance('u').first, 15);
      // Le total gagné ne baisse jamais.
      expect(await wallet.watchLifetimeEarned('u').first, 30);
      final txs = await wallet.watchTransactions('u').first;
      expect(txs.map((t) => t.points), containsAll([30, -15]));
    });

    test('refuse si le solde est insuffisant', () async {
      await wallet.creditPoints(uid: 'u', points: 10, label: 'Bonus');
      expect(
        wallet.redeem(
            uid: 'u', method: RedemptionMethod.airtime, points: 15, recipientPhone: '+237'),
        throwsStateError,
      );
      expect(await wallet.watchBalance('u').first, 10);
    });
  });
}
