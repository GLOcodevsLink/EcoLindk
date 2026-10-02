import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecolindk/admin/services/admin_repository.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/models/user_role.dart';
import 'package:ecolindk/models/wallet_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late AdminRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = AdminRepository(firestore: db);
  });

  test('isAdmin is true only with an admins/{uid} document', () async {
    await db.collection('admins').doc('boss').set({'addedAt': Timestamp.now()});
    expect(await repo.isAdmin('boss'), isTrue);
    expect(await repo.isAdmin('someone'), isFalse);
  });

  test('watchUsers reads the user documents written at registration, newest first', () async {
    await db.collection('users').doc('old').set({
      'fullName': 'Awa Ndi',
      'email': 'awa@x.cm',
      'role': 'household',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await db.collection('users').doc('new').set({
      'fullName': 'Paul',
      'role': 'collector',
      'workStatus': 'company',
      'companyName': 'Hysacam',
      'collectionZones': [
        {'country': 'Cameroun', 'countryCode': 'CM', 'city': 'Yaoundé', 'neighborhood': 'Bastos'},
      ],
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });
    await db.collection('users').doc('unfinished').set({'email': 'x@x.cm', 'role': null});

    final users = await repo.watchUsers().first;
    expect(users.map((u) => u.uid), ['new', 'old', 'unfinished']);
    expect(users[0].role, UserRole.collector);
    expect(users[0].workStatus, WorkStatus.company);
    expect(users[0].zones.single.label, 'Cameroun → Yaoundé → Bastos');
    expect(users[1].role, UserRole.household);
    expect(users[2].role, isNull);
    expect(users[2].displayName, 'x@x.cm');
  });

  test('watchRedemptions gathers every provider wallet and keeps the owner uid', () async {
    Future<void> redemption(String uid, DateTime at) => db.collection('wallets').doc(uid).collection('redemptions').add({
          'method': 'airtime',
          'pointsSpent': 15,
          'amountFcfa': 500,
          'recipientPhone': '+237670000000',
          'status': 'completed',
          'createdAt': Timestamp.fromDate(at),
        });
    await redemption('h1', DateTime(2026, 9, 1));
    await redemption('h2', DateTime(2026, 9, 20));

    final list = await repo.watchRedemptions().first;
    expect(list.map((r) => r.uid), ['h2', 'h1']);
    expect(list.first.request.status, RedemptionStatus.completed);
  });

  test('watchWallets maps balances, with the lifetime fallback of WalletService', () async {
    await db.collection('wallets').doc('h1').set({'pointsBalance': 30, 'lifetimeEarned': 80});
    await db.collection('wallets').doc('h2').set({'pointsBalance': 12});
    final wallets = await repo.watchWallets().first;
    expect(wallets['h1']!.lifetimeEarned, 80);
    expect(wallets['h2']!.lifetimeEarned, 12);
  });

  group('cancelPost', () {
    Future<void> post(String id, String status) =>
        db.collection('collectionRequests').doc(id).set({'householdUid': 'h1', 'status': status});

    test('cancels a pending post and marks it as removed by the admin', () async {
      await post('p1', 'pending');
      await repo.cancelPost('p1');
      final data = (await db.collection('collectionRequests').doc('p1').get()).data()!;
      expect(data['status'], RequestStatus.cancelled.name);
      expect(data['cancelledByAdmin'], isTrue);
    });

    test('refuses a post a collector already accepted, without writing', () async {
      await post('p2', 'accepted');
      await expectLater(repo.cancelPost('p2'), throwsA(isA<StateError>()));
      final data = (await db.collection('collectionRequests').doc('p2').get()).data()!;
      expect(data['status'], 'accepted');
      expect(data.containsKey('cancelledByAdmin'), isFalse);
    });
  });
}
