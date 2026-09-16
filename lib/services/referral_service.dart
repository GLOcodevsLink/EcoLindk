import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/rewards_config.dart';
import '../models/app_notification.dart';
import '../models/referral.dart';
import '../models/wallet_models.dart';
import 'notification_service.dart';

/// Parrainage — voir règles métier #12/#22 : un filleul ne rapporte des
/// points à son parrain que lorsqu'il termine sa première collecte
/// qualifiante (jamais à la simple création du compte), et ce crédit ne peut
/// avoir lieu qu'une seule fois par filleul. Les Collecteurs n'ont pas de
/// portefeuille de parrainage — ce service n'est utilisé que pour des
/// Fournisseurs de déchets.
///
/// Schéma Firestore :
/// - `referralCodes/{code}` -> `{ ownerUid }` : index public en lecture,
///   comme `phone_lookup`, pour retrouver le parrain à l'inscription.
/// - `referrals/{referrerUid}` -> résumé (`code`, `referralsCount`,
///   `pointsEarned`), sous-collection `uses/{referredUid}` -> statut par
///   filleul (`pending` puis `qualified`, jamais l'inverse).
class ReferralService {
  ReferralService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _referrer(String uid) =>
      _firestore.collection('referrals').doc(uid);
  CollectionReference<Map<String, dynamic>> _uses(String uid) =>
      _referrer(uid).collection('uses');
  CollectionReference<Map<String, dynamic>> get _codes =>
      _firestore.collection('referralCodes');

  /// Retourne le code existant de [uid], ou en alloue un nouveau (3 lettres
  /// dérivées de [firstName] + 3 chiffres), garanti unique via une
  /// transaction sur `referralCodes/{code}`.
  Future<String> ensureCode(String uid, String firstName) async {
    final existing = await _referrer(uid).get();
    final current = existing.data()?['code'] as String?;
    if (current != null) return current;

    final letters = firstName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final base = letters.isEmpty
        ? 'ECO'
        : (letters.length >= 3 ? letters.substring(0, 3) : letters.padRight(3, 'X'));
    final rnd = Random();

    for (var attempt = 0; attempt < 25; attempt++) {
      final code = '$base${100 + rnd.nextInt(900)}';
      final codeDoc = _codes.doc(code);
      final created = await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(codeDoc);
        if (snap.exists) return false;
        tx.set(codeDoc, {'ownerUid': uid});
        tx.set(_referrer(uid),
            {'code': code, 'referralsCount': 0, 'pointsEarned': 0},
            SetOptions(merge: true));
        return true;
      });
      if (created) return code;
    }
    throw StateError('could-not-allocate-referral-code');
  }

  Future<String?> ownerUidForCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final doc = await _codes.doc(normalized).get();
    return doc.data()?['ownerUid'] as String?;
  }

  /// Enregistre l'usage d'un code au moment de l'inscription du filleul —
  /// statut `pending` jusqu'à [creditIfQualifying]. `referredUid` comme id de
  /// document : un même filleul ne peut apparaître qu'une fois chez un
  /// parrain donné.
  Future<void> recordReferralUse({
    required String referrerUid,
    required String referredUid,
    required String referredName,
  }) {
    return _uses(referrerUid).doc(referredUid).set({
      'referredName': referredName,
      'status': ReferralStatus.pending.name,
      'pointsAwarded': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'qualifiedAt': null,
    });
  }

  Stream<Map<String, dynamic>?> watchSummary(String uid) =>
      _referrer(uid).snapshots().map((d) => d.data());

  Stream<List<ReferralUse>> watchHistory(String uid) => _uses(uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((q) => q.docs.map(ReferralUse.fromDoc).toList());

  /// Appelé par [uid] lui-même (le filleul), après une de ses collectes
  /// complétées (voir CollectionService.settleCompletedRequest) : si son
  /// usage est encore `pending` et que cette collecte atteint le poids
  /// minimum qualifiant, fait passer SA PROPRE ligne à `qualified` — jamais
  /// plus d'une fois (voir firestore.rules : seul le filleul peut écrire ici,
  /// et seulement pending -> qualified). Ne crédite pas encore le parrain :
  /// voir [claimPendingRewards], qu'il exécute lui-même de son côté.
  Future<void> creditIfQualifying({
    required String uid,
    required double weightKg,
  }) async {
    if (weightKg < RewardsConfig.qualifyingCollectionMinKg) return;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final referrerUid = userDoc.data()?['referredBy'] as String?;
    if (referrerUid == null) return;

    final useRef = _uses(referrerUid).doc(uid);
    final useSnap = await useRef.get();
    if (!useSnap.exists || useSnap.data()?['status'] != ReferralStatus.pending.name) {
      return; // déjà qualifié, ou pas de ligne (ne devrait pas arriver)
    }
    await useRef.update({
      'status': ReferralStatus.qualified.name,
      'pointsAwarded': RewardsConfig.referralPoints,
      'qualifiedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Appelé par le PARRAIN lui-même (typiquement à l'ouverture de
  /// [ReferEarnScreen]) : cherche parmi ses filleuls ceux `qualified` dont
  /// les points n'ont pas encore été réclamés, les crédite dans son PROPRE
  /// portefeuille et met à jour son PROPRE résumé — voir firestore.rules :
  /// aucune de ces écritures ne touche jamais les données d'un autre
  /// utilisateur. Idempotent par filleul (id de transaction déterministe).
  Future<void> claimPendingRewards(String referrerUid) async {
    final uses = await _uses(referrerUid)
        .where('status', isEqualTo: ReferralStatus.qualified.name)
        .get();

    for (final useDoc in uses.docs) {
      final referredUid = useDoc.id;
      final txRef = _firestore
          .collection('wallets')
          .doc(referrerUid)
          .collection('transactions')
          .doc('referral_$referredUid');
      final referrerRef = _referrer(referrerUid);
      final walletRef = _firestore.collection('wallets').doc(referrerUid);

      final claimed = await _firestore.runTransaction<bool>((tx) async {
        final txSnap = await tx.get(txRef);
        if (txSnap.exists) return false; // déjà réclamé pour ce filleul

        final walletSnap = await tx.get(walletRef);
        final balance = (walletSnap.data()?['pointsBalance'] as num?)?.toInt() ?? 0;
        tx.set(walletRef, {'pointsBalance': balance + RewardsConfig.referralPoints},
            SetOptions(merge: true));
        tx.set(txRef, {
          'type': PointsTxType.earnedReferral.name,
          'points': RewardsConfig.referralPoints,
          'label': 'Parrainage réussi',
          'relatedRequestId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final referrerSnap = await tx.get(referrerRef);
        final count = (referrerSnap.data()?['referralsCount'] as num?)?.toInt() ?? 0;
        final earned = (referrerSnap.data()?['pointsEarned'] as num?)?.toInt() ?? 0;
        tx.set(
            referrerRef,
            {
              'referralsCount': count + 1,
              'pointsEarned': earned + RewardsConfig.referralPoints,
            },
            SetOptions(merge: true));
        return true;
      });

      if (claimed) {
        await NotificationService().notify(
          uid: referrerUid,
          type: NotificationType.referralCompleted,
          title: 'Parrainage réussi 🎉',
          body: 'Un de vos filleuls a complété sa première collecte — '
              '+${RewardsConfig.referralPoints} points.',
        );
      }
    }
  }
}
