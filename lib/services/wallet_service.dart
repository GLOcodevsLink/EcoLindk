import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/rewards_config.dart';
import '../models/app_notification.dart';
import '../models/collection_request.dart';
import '../models/wallet_models.dart';
import 'notification_service.dart';

/// Portefeuille à points — **le seul** mécanisme de récompense de l'app
/// (règle métier #22 : "Do not invent a second reward system"). Stocké dans
/// `wallets/{uid}` (solde) + sous-collections `transactions` (historique) et
/// `redemptions` (conversions en airtime/mobile data/retrait/envoi). Toute
/// valeur FCFA affichée dérive de [RewardsConfig] — jamais recalculée
/// ailleurs.
class WalletService {
  WalletService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _wallet(String uid) =>
      _firestore.collection('wallets').doc(uid);
  CollectionReference<Map<String, dynamic>> _txs(String uid) =>
      _wallet(uid).collection('transactions');
  CollectionReference<Map<String, dynamic>> _redemptions(String uid) =>
      _wallet(uid).collection('redemptions');

  Stream<int> watchBalance(String uid) => _wallet(uid)
      .snapshots()
      .map((d) => (d.data()?['pointsBalance'] as num?)?.toInt() ?? 0);

  /// Total de points gagnés depuis toujours (ne descend jamais, contrairement
  /// au solde qui baisse à chaque conversion) — affiché sur le Portefeuille
  /// ("Total gagné"). Repli sur le solde courant pour les portefeuilles créés
  /// avant l'ajout de ce champ (jamais 0 par défaut, qui serait faux dès que
  /// le solde est positif).
  Stream<int> watchLifetimeEarned(String uid) => _wallet(uid).snapshots().map((d) {
        final data = d.data();
        final lifetime = (data?['lifetimeEarned'] as num?)?.toInt();
        if (lifetime != null) return lifetime;
        return (data?['pointsBalance'] as num?)?.toInt() ?? 0;
      });

  Stream<List<PointsTransaction>> watchTransactions(String uid) => _txs(uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((q) => q.docs.map(PointsTransaction.fromDoc).toList());

  Stream<List<RedemptionRequest>> watchRedemptions(String uid) =>
      _redemptions(uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((q) => q.docs.map(RedemptionRequest.fromDoc).toList());

  /// Crédite [points] (ex. à la fin d'une collecte, ou pour un parrainage
  /// réussi — voir CollectionService/ReferralService) et journalise le
  /// mouvement, dans la même transaction pour rester cohérent.
  Future<void> creditPoints({
    required String uid,
    required int points,
    required String label,
    String? relatedRequestId,
    PointsTxType type = PointsTxType.earnedCollection,
  }) {
    final walletRef = _wallet(uid);
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(walletRef);
      final data = snap.data();
      final current = (data?['pointsBalance'] as num?)?.toInt() ?? 0;
      // `lifetimeEarned` : repli sur le solde courant s'il n'existe pas
      // encore (portefeuille créé avant ce champ), pour ne pas perdre
      // l'historique déjà accumulé dans le solde.
      final lifetime = (data?['lifetimeEarned'] as num?)?.toInt() ?? current;
      tx.set(
          walletRef,
          {
            'pointsBalance': current + points,
            'lifetimeEarned': lifetime + points,
          },
          SetOptions(merge: true));
      tx.set(_txs(uid).doc(), {
        'type': type.name,
        'points': points,
        'label': label,
        'relatedRequestId': relatedRequestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Réclame, dans SON PROPRE portefeuille, les points d'une [request]
  /// complétée dont le Fournisseur est propriétaire (voir
  /// CollectionService.settleCompletedRequest et firestore.rules : le
  /// Collecteur n'écrit jamais directement dans le portefeuille de qui que
  /// ce soit — il se contente de renseigner `pointsEarned` sur la demande,
  /// que son propriétaire vient ensuite chercher ici). Idempotent : l'id de
  /// la transaction est l'id de la demande, donc un second appel pour la
  /// même collecte ne recrédite rien (voir aussi `allow update: if false`
  /// sur `transactions` dans les règles).
  Future<void> claimCollectionPoints(CollectionRequest request) async {
    if (request.status != RequestStatus.completed || request.pointsEarned == null) return;
    final uid = request.householdUid;
    final walletRef = _wallet(uid);
    final txRef = _txs(uid).doc(request.id);

    final credited = await _firestore.runTransaction<bool>((tx) async {
      final txSnap = await tx.get(txRef);
      if (txSnap.exists) return false; // déjà réclamé
      final walletData = (await tx.get(walletRef)).data();
      final current = (walletData?['pointsBalance'] as num?)?.toInt() ?? 0;
      final lifetime = (walletData?['lifetimeEarned'] as num?)?.toInt() ?? current;
      tx.set(
          walletRef,
          {
            'pointsBalance': current + request.pointsEarned!,
            'lifetimeEarned': lifetime + request.pointsEarned!,
          },
          SetOptions(merge: true));
      tx.set(txRef, {
        'type': PointsTxType.earnedCollection.name,
        'points': request.pointsEarned,
        'label': 'Collecte ${request.reference}',
        'relatedRequestId': request.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });

    if (!credited) return;
    await NotificationService().notify(
      uid: uid,
      type: NotificationType.pointsCredited,
      title: 'Points crédités 🎉',
      body: '+${request.pointsEarned} points pour ${request.reference}.',
      relatedRequestId: request.id,
    );
  }

  /// Convertit [points] en FCFA via [method] (crédit airtime/mobile data,
  /// retrait, ou envoi à un proche au numéro [recipientPhone]).
  ///
  /// **Simulé** : aucune vraie API de paiement/mobile money n'est encore
  /// branchée (voir la suite prévue du projet). Débite réellement le solde
  /// de points (Firestore, transactionnel — deux appels concurrents ne
  /// peuvent pas descendre le solde sous zéro), puis marque la demande
  /// "completed" après un court délai pour donner un retour honnête, sans
  /// jamais prétendre qu'un virement réel a eu lieu.
  Future<RedemptionRequest> redeem({
    required String uid,
    required RedemptionMethod method,
    required int points,
    required String recipientPhone,
  }) async {
    final amount = RewardsConfig.fcfaForPoints(points);
    final docRef = _redemptions(uid).doc();
    final walletRef = _wallet(uid);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(walletRef);
      final current = (snap.data()?['pointsBalance'] as num?)?.toInt() ?? 0;
      if (current < points) {
        throw StateError('insufficient-points');
      }
      tx.set(walletRef, {'pointsBalance': current - points}, SetOptions(merge: true));
      tx.set(docRef, {
        'method': method.name,
        'pointsSpent': points,
        'amountFcfa': amount,
        'recipientPhone': recipientPhone,
        'status': RedemptionStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(_txs(uid).doc(), {
        'type': PointsTxType.redeemed.name,
        'points': -points,
        'label': 'Conversion — ${method.name}',
        'relatedRequestId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    await Future.delayed(const Duration(milliseconds: 900));
    await docRef.update({'status': RedemptionStatus.completed.name});
    final snap = await docRef.get();
    return RedemptionRequest.fromDoc(snap);
  }
}
