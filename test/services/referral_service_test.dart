import 'package:ecolindk/core/rewards_config.dart';
import 'package:ecolindk/services/referral_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ReferralService referrals;

  setUp(() {
    db = FakeFirebaseFirestore();
    referrals = ReferralService(firestore: db);
  });

  group('ensureCode', () {
    test('3 lettres du prénom + 3 chiffres, stable ensuite', () async {
      final code = await referrals.ensureCode('parrain', 'Élodie');
      expect(code, matches(RegExp(r'^LOD\d{3}$'))); // accents retirés
      expect(await referrals.ensureCode('parrain', 'Autre'), code);
      expect(await referrals.ownerUidForCode(code.toLowerCase()), 'parrain');
    });

    test('prénom court ou sans lettres', () async {
      expect(await referrals.ensureCode('a', 'Jo'), matches(RegExp(r'^JOX\d{3}$')));
      expect(await referrals.ensureCode('b', '123'), matches(RegExp(r'^ECO\d{3}$')));
    });

    test('code inconnu ou vide → null', () async {
      expect(await referrals.ownerUidForCode('ZZZ999'), isNull);
      expect(await referrals.ownerUidForCode('  '), isNull);
    });
  });

  group('parcours complet', () {
    setUp(() async {
      await db.collection('users').doc('filleul').set({'referredBy': 'parrain'});
      await referrals.recordReferralUse(
          referrerUid: 'parrain', referredUid: 'filleul', referredName: 'Awa');
    });

    Future<String?> status() async =>
        (await db.doc('referrals/parrain/uses/filleul').get()).data()?['status'] as String?;

    test('une collecte trop légère ne qualifie pas', () async {
      await referrals.creditIfQualifying(uid: 'filleul', weightKg: 0.5);
      expect(await status(), 'pending');
    });

    test('qualification puis crédit du parrain une seule fois', () async {
      await referrals.creditIfQualifying(uid: 'filleul', weightKg: 2);
      expect(await status(), 'qualified');

      await referrals.claimPendingRewards('parrain');
      await referrals.claimPendingRewards('parrain');

      final wallet = (await db.doc('wallets/parrain').get()).data()!;
      expect(wallet['pointsBalance'], RewardsConfig.referralPoints);
      expect(wallet['lifetimeEarned'], RewardsConfig.referralPoints);
      final summary = (await db.doc('referrals/parrain').get()).data()!;
      expect(summary['referralsCount'], 1);
      expect(summary['pointsEarned'], RewardsConfig.referralPoints);
    });

    test('rien pour un utilisateur sans parrain', () async {
      await db.collection('users').doc('seul').set({});
      await referrals.creditIfQualifying(uid: 'seul', weightKg: 5);
      expect(await status(), 'pending');
    });
  });
}
