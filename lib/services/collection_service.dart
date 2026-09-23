import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../core/rewards_config.dart';
import '../models/app_notification.dart';
import '../models/collection_request.dart';
import 'notification_service.dart';
import 'referral_service.dart';
import 'stockimg_client.dart';
import 'wallet_service.dart';

/// CRUD + logique métier des demandes de collecte (`collectionRequests/{id}`
/// dans Firestore, photo hébergée sur StockImg — seule son URL est stockée).
///
/// Ce service porte aussi les actions "côté Collecteur" ([acceptRequest],
/// [submitCollectionResult]) et "côté Fournisseur" ([confirmCollectionResult],
/// [rejectCollectionResult]) — voir firestore.rules pour qui peut écrire quoi.
class CollectionService {
  CollectionService({FirebaseFirestore? firestore, StockImgClient? stockImg})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _stockImg = stockImg ?? StockImgClient();

  final FirebaseFirestore _firestore;
  final StockImgClient _stockImg;

  // Rayon (km) au-delà duquel un Collecteur n'est plus notifié d'un nouveau
  // post (demande explicite : "when a post is done by a nearby waste
  // provider to a collector, the collector is notified") — même valeur que
  // le filtre "Près de moi" de CollectorMapScreen, pour rester cohérent.
  static const _nearbyRadiusKm = 10.0;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('collectionRequests');

  CollectionReference<Map<String, dynamic>> get _collectorLocations =>
      _firestore.collection('collectorLocations');

  /// Enregistre/actualise le point de référence d'un Collecteur (géocodé
  /// depuis sa "zone de collecte" — voir CollectorSetupScreen/ProfileScreen)
  /// — sert au filtre "Près de moi" ET à [createRequest] pour notifier les
  /// collecteurs proches d'un nouveau post. Document séparé de `users/{uid}`
  /// (voir firestore.rules) : n'importe quel utilisateur authentifié doit
  /// pouvoir le LIRE pour calculer une distance, ce qui serait beaucoup trop
  /// large comme permission sur la fiche utilisateur complète.
  Future<void> setCollectorLocation(String uid, double latitude, double longitude) =>
      _collectorLocations.doc(uid).set({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Relit le point de référence géocodé d'un Collecteur (sa "zone de
  /// collecte", voir [setCollectorLocation]) — utilisé par CollectorMapScreen
  /// pour proposer les posts proches de la zone déclarée, EN PLUS de ceux
  /// proches de sa position GPS du moment (demande explicite : les deux
  /// sources doivent compter, pas seulement le GPS live). `null` si le
  /// collecteur n'a pas encore de zone géocodée (échec de géocodage passé,
  /// ou compte tout juste créé).
  Future<ll.LatLng?> getCollectorLocation(String uid) async {
    final snap = await _collectorLocations.doc(uid).get();
    final lat = (snap.data()?['latitude'] as num?)?.toDouble();
    final lng = (snap.data()?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return ll.LatLng(lat, lng);
  }

  /// Envoie la photo sur StockImg et renvoie son URL publique (stockée
  /// ensuite dans `imageUrl` de la demande). Lève [StockImgException].
  Future<String> uploadWastePhoto(String uid, File file) =>
      _stockImg.uploadFile(file);

  Future<CollectionRequest> createRequest({
    required String householdUid,
    required String householdName,
    required String imageUrl,
    required String description,
    required WasteCategory category,
    required String quantityRange,
    required bool aiRequested,
    WasteCategory? aiSuggestedCategory,
    double? aiConfidence,
    required String address,
    required double latitude,
    required double longitude,
    required bool locationIsApproximate,
  }) async {
    final draft = CollectionRequest(
      id: '',
      householdUid: householdUid,
      householdName: householdName,
      imageUrl: imageUrl,
      description: description,
      category: category,
      quantityRange: quantityRange,
      aiRequested: aiRequested,
      aiSuggestedCategory: aiSuggestedCategory,
      aiConfidence: aiConfidence,
      address: address,
      latitude: latitude,
      longitude: longitude,
      locationIsApproximate: locationIsApproximate,
      status: RequestStatus.pending,
      createdAt: DateTime.now(),
    );
    final docRef = await _requests.add(draft.toCreateMap());

    await NotificationService(firestore: _firestore).notify(
      uid: householdUid,
      type: NotificationType.requestSubmitted,
      title: 'Demande envoyée',
      body: 'Votre demande de collecte a bien été enregistrée.',
      relatedRequestId: docRef.id,
    );

    await _notifyNearbyCollectors(
        requestId: docRef.id, latitude: latitude, longitude: longitude, category: category);

    final snap = await docRef.get();
    return CollectionRequest.fromDoc(snap);
  }

  /// Notifie chaque Collecteur dont la zone géocodée (voir
  /// [setCollectorLocation]) est à moins de [_nearbyRadiusKm] du nouveau
  /// post — demande explicite : "when a post is done by a nearby waste
  /// provider to a collector, the collector is notified of the post". Pas de
  /// Cloud Function (hors plan Firebase gratuit, voir NotificationService) :
  /// calculé côté client, depuis l'appareil du Fournisseur qui vient de
  /// poster, jamais bloquant pour la création du post elle-même si ça échoue.
  Future<void> _notifyNearbyCollectors({
    required String requestId,
    required double latitude,
    required double longitude,
    required WasteCategory category,
  }) async {
    try {
      final postPoint = ll.LatLng(latitude, longitude);
      const distance = ll.Distance();
      final locations = await _collectorLocations.get();
      for (final doc in locations.docs) {
        final lat = (doc.data()['latitude'] as num?)?.toDouble();
        final lng = (doc.data()['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final km = distance.as(ll.LengthUnit.Kilometer, postPoint, ll.LatLng(lat, lng));
        if (km > _nearbyRadiusKm) continue;
        await NotificationService(firestore: _firestore).notify(
          uid: doc.id,
          type: NotificationType.newNearbyPost,
          title: 'Nouvelle collecte près de vous',
          body: 'Une collecte de ${category.label(true)} vient d\'être postée à '
              '${km.toStringAsFixed(1)} km de votre zone.',
          relatedRequestId: requestId,
        );
      }
    } catch (_) {
      // Best-effort : une notification manquée n'empêche jamais la création
      // du post lui-même (voir doc ci-dessus).
    }
  }

  Stream<CollectionRequest?> watchRequest(String id) => _requests
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? CollectionRequest.fromDoc(d) : null);

  Stream<List<CollectionRequest>> watchActiveRequests(String householdUid) =>
      _requests
          .where('householdUid', isEqualTo: householdUid)
          .where('status', whereIn: ['pending', 'accepted', 'inProgress'])
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((q) => q.docs.map(CollectionRequest.fromDoc).toList());

  Stream<List<CollectionRequest>> watchHistory(String householdUid) =>
      _requests
          .where('householdUid', isEqualTo: householdUid)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((q) => q.docs.map(CollectionRequest.fromDoc).toList());

  /// Toutes les demandes encore libres (`pending`, sans collecteur assigné)
  /// tous fournisseurs confondus — voir CollectorMapScreen/CollectorTasksScreen :
  /// c'est le "marché" que parcourt un Collecteur pour trouver une collecte à
  /// accepter (voir firestore.rules : un collecteur peut lire toute demande
  /// `pending`, pas seulement les siennes).
  Stream<List<CollectionRequest>> watchAvailableRequests() => _requests
      .where('status', isEqualTo: RequestStatus.pending.name)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((q) => q.docs.map(CollectionRequest.fromDoc).toList());

  /// Demandes déjà acceptées par [collectorUid], pas encore terminées — le
  /// pendant [watchActiveRequests] côté Collecteur (voir
  /// CollectorTasksScreen, onglet "En cours").
  Stream<List<CollectionRequest>> watchCollectorActiveRequests(String collectorUid) =>
      _requests
          .where('collectorUid', isEqualTo: collectorUid)
          .where('status', whereIn: ['accepted', 'inProgress'])
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((q) => q.docs.map(CollectionRequest.fromDoc).toList());

  /// Demandes terminées/annulées où [collectorUid] était assigné — le
  /// pendant [watchHistory] côté Collecteur (voir CollectorHistoryScreen).
  Stream<List<CollectionRequest>> watchCollectorHistory(String collectorUid) =>
      _requests
          .where('collectorUid', isEqualTo: collectorUid)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((q) => q.docs.map(CollectionRequest.fromDoc).toList());

  /// Tous les déchets postés par [householdUid], quel que soit leur statut —
  /// voir MyPostsScreen : un flux brut de "mes posts", distinct du suivi par
  /// étape de MyCollectionsScreen (en cours / historique).
  Stream<List<CollectionRequest>> watchAllRequests(String householdUid) =>
      _requests
          .where('householdUid', isEqualTo: householdUid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((q) => q.docs.map(CollectionRequest.fromDoc).toList());

  /// Un déchet posté peut être annulé par son propriétaire tant qu'aucun
  /// collecteur ne l'a encore accepté.
  Future<void> cancelRequest(String requestId) =>
      _requests.doc(requestId).update({'status': RequestStatus.cancelled.name});

  /// Règle métier centrale : une demande n'est acceptée que par un seul
  /// collecteur (#7/#22). Transaction qui échoue si `collectorUid` n'est
  /// déjà plus `null` (un autre collecteur a été plus rapide) ou si le
  /// statut n'est plus `pending`.
  Future<void> acceptRequest(
    String requestId, {
    required String collectorUid,
    required String collectorName,
  }) async {
    final ref = _requests.doc(requestId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null ||
          data['collectorUid'] != null ||
          data['status'] != RequestStatus.pending.name) {
        throw StateError('already-accepted');
      }
      tx.update(ref, {
        'collectorUid': collectorUid,
        'collectorName': collectorName,
        'status': RequestStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });

    final snap = await ref.get();
    final householdUid = snap.data()?['householdUid'] as String?;
    if (householdUid != null) {
      await NotificationService(firestore: _firestore).notify(
        uid: householdUid,
        type: NotificationType.requestAccepted,
        title: 'Collecteur assigné',
        body: '$collectorName a accepté votre demande de collecte.',
        relatedRequestId: requestId,
      );
    }
  }

  /// Le collecteur soumet poids + prix APRÈS la rencontre avec le
  /// fournisseur (demande explicite) — ni l'un ni l'autre ne sont
  /// définitifs tant que le fournisseur n'a pas scanné le QR et confirmé
  /// (voir [confirmCollectionResult]). [weightKg] doit être dans la
  /// fourchette annoncée par le fournisseur à la création du post — vérifié
  /// ici en plus de l'UI (jamais confiance uniquement dans un contrôle
  /// client, voir [CollectionRequest.quantityRange]/[QuantityRangeBounds]).
  Future<void> submitCollectionResult(
    String requestId, {
    required double weightKg,
    required double priceFcfa,
  }) async {
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    final request = CollectionRequest.fromDoc(snap);

    final (min, max) = request.quantityRange.weightBoundsKg;
    if (weightKg < min || weightKg > max) {
      throw const FormatException('weight-out-of-range');
    }

    await ref.update({
      'status': RequestStatus.inProgress.name,
      'pendingWeightKg': weightKg,
      'pendingPriceFcfa': priceFcfa,
    });

    await NotificationService(firestore: _firestore).notify(
      uid: request.householdUid,
      type: NotificationType.statusChanged,
      title: 'Collecte à confirmer',
      body:
          '${request.collectorName ?? 'Le collecteur'} a soumis ${weightKg.toStringAsFixed(1)} kg '
          'pour ${priceFcfa.toStringAsFixed(0)} FCFA. Scannez son code pour confirmer.',
      relatedRequestId: requestId,
    );
  }

  /// Le fournisseur scanne le QR du collecteur puis accepte : poids/prix
  /// soumis deviennent définitifs, points calculés depuis le barème unique
  /// [RewardsConfig] à partir du poids réel (jamais du prix négocié, qui
  /// reste un paiement direct entre les deux parties — voir doc de la
  /// classe). Écrit sur LA DEMANDE, jamais directement dans le portefeuille
  /// du Fournisseur (voir firestore.rules/[settleCompletedRequest]).
  Future<void> confirmCollectionResult(String requestId) async {
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    final request = CollectionRequest.fromDoc(snap);
    final weight = request.pendingWeightKg;
    final price = request.pendingPriceFcfa;
    if (weight == null || price == null) return;

    final points = RewardsConfig.pointsForCollection(request.category, weight).round();

    await ref.update({
      'status': RequestStatus.completed.name,
      'weightKg': weight,
      'valueFcfa': price,
      'pointsEarned': points,
      'pendingWeightKg': null,
      'pendingPriceFcfa': null,
      'completedAt': FieldValue.serverTimestamp(),
    });

    if (request.collectorUid != null) {
      await NotificationService(firestore: _firestore).notify(
        uid: request.collectorUid!,
        type: NotificationType.requestCompleted,
        title: 'Collecte confirmée ✅',
        body: 'Le fournisseur a confirmé la collecte : ${weight.toStringAsFixed(1)} kg.',
        relatedRequestId: requestId,
      );
    }
  }

  /// Le fournisseur refuse le poids/prix soumis — retour à [RequestStatus.accepted],
  /// le collecteur est notifié pour resoumettre (demande explicite : "if it
  /// is rejected it sends to the collector a message so that it can refill
  /// the form").
  Future<void> rejectCollectionResult(String requestId) async {
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    final request = CollectionRequest.fromDoc(snap);

    await ref.update({
      'status': RequestStatus.accepted.name,
      'pendingWeightKg': null,
      'pendingPriceFcfa': null,
    });

    if (request.collectorUid != null) {
      await NotificationService(firestore: _firestore).notify(
        uid: request.collectorUid!,
        type: NotificationType.collectionRejected,
        title: 'Collecte refusée',
        body: 'Le fournisseur a refusé le poids/prix soumis. Vérifiez et renvoyez.',
        relatedRequestId: requestId,
      );
    }
  }
}

/// À appeler côté client du Fournisseur de déchets chaque fois qu'une de ses
/// demandes complétées lui est affichée (voir RequestStatusScreen,
/// CollectionHistoryScreen, CollectionDetailScreen) : réclame ses propres
/// points dans son propre portefeuille et tente de qualifier son parrainage
/// — les deux opérations n'écrivent jamais que les données du Fournisseur
/// lui-même (voir firestore.rules) et sont sans danger à rappeler plusieurs
/// fois (idempotentes).
Future<void> settleCompletedRequest(CollectionRequest request,
    {FirebaseFirestore? firestore}) async {
  if (request.status != RequestStatus.completed) return;
  await WalletService(firestore: firestore).claimCollectionPoints(request);
  await ReferralService(firestore: firestore)
      .creditIfQualifying(uid: request.householdUid, weightKg: request.weightKg ?? 0);
}
