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

  // Lecture directe (get) : le premier événement de `snapshots()` de
  // fake_cloud_firestore peut être périmé juste après une transaction.
  Future<int?> field(String uid, String name) async =>
      ((await db.doc('wallets/$uid').get()).data()?[name] as num?)?.toInt();
  Future<int?> balance(String uid) => field(uid, 'pointsBalance');
  Future<List<int>> txPoints(String uid) async =>
      (await db.collection('wallets/$uid/transactions').get())
          .docs
          .map((d) => (d.data()['points'] as num).toInt())
          .toList();

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
    expect(await balance('u'), 50);
    expect(await field('u', 'lifetimeEarned'), 50);
    expect(await txPoints('u'), unorderedEquals([30, 20]));
  });

  group('claimCollectionPoints', () {
    test('crédite une fois, même appelé plusieurs fois', () async {
      await wallet.claimCollectionPoints(completed());
      await wallet.claimCollectionPoints(completed());
      expect(await balance('house'), 40);
      final notifs = await db.collection('notifications').doc('house').collection('items').get();
      expect(notifs.docs.single.data()['type'], 'pointsCredited');
    });

    test('ignore une demande non terminée ou sans points', () async {
      await wallet.claimCollectionPoints(completed(status: RequestStatus.inProgress));
      await wallet.claimCollectionPoints(completed(points: null));
      expect(await balance('house'), isNull);
    });
  });

  group('redeem (conversion simulée)', () {
    test('débite le solde et enregistre la conversion', () async {
      await wallet.creditPoints(uid: 'u', points: 30, label: 'Bonus');
      final r = await wallet.redeem(
          uid: 'u', method: RedemptionMethod.airtime, points: 15, recipientPhone: '+237650000000');

      expect(r.status, RedemptionStatus.completed);
      expect(await balance('u'), 15);
      // Pas de vérification de `lifetimeEarned` ici : fake_cloud_firestore
      // ignore SetOptions(merge: true) dans une transaction et efface donc ce
      // champ, alors que le vrai Firestore le conserve.
      expect(await txPoints('u'), unorderedEquals([30, -15]));
      final redemption = (await db.collection('wallets/u/redemptions').get()).docs.single.data();
      expect(redemption['amountFcfa'], 500);
      expect(redemption['status'], 'completed');
    });

    test('refuse si le solde est insuffisant', () async {
      await wallet.creditPoints(uid: 'u', points: 10, label: 'Bonus');
      await expectLater(
        wallet.redeem(
            uid: 'u', method: RedemptionMethod.airtime, points: 15, recipientPhone: '+237'),
        throwsStateError,
      );
      expect(await balance('u'), 10);
    });
  });
}
