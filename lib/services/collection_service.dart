import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../core/geo_config.dart';
import '../core/rewards_config.dart';
import '../models/app_notification.dart';
import '../models/collection_request.dart';
import 'geocoding_service.dart';
import 'live_tracking_service.dart';
import 'notification_service.dart';
import 'referral_service.dart';
import 'wallet_service.dart';
import 'waste_photo_service.dart';
import 'zone_matching.dart';

/// CRUD + logique métier des demandes de collecte (`collectionRequests/{id}`
/// dans Firestore ; la photo est elle aussi dans Firestore, voir
/// WastePhotoService — seule sa référence est stockée sur la demande).
///
/// Ce service porte aussi les actions "côté Collecteur" ([acceptRequest],
/// [submitCollectionResult]) et "côté Fournisseur" ([confirmCollectionResult],
/// [rejectCollectionResult]) — voir firestore.rules pour qui peut écrire quoi.
class CollectionService {
  CollectionService({
    FirebaseFirestore? firestore,
    WastePhotoService? photos,
    GeocodingService? geocoding,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _photos = photos ?? WastePhotoService(firestore: firestore),
        _geocoding = geocoding ?? GeocodingService();

  final FirebaseFirestore _firestore;
  final WastePhotoService _photos;
  final GeocodingService _geocoding;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('collectionRequests');

  CollectionReference<Map<String, dynamic>> get _collectorLocations =>
      _firestore.collection('collectorLocations');

  /// Ancien format de `collectorLocations/{uid}` : un seul point. Les zones
  /// de collecte s'enregistrent désormais via CollectorZoneService (liste
  /// `zones`) ; gardé pour la compatibilité et les tests.
  Future<void> setCollectorLocation(String uid, double latitude, double longitude) =>
      _collectorLocations.doc(uid).set({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Premier point connu des zones d'un Collecteur (voir
  /// [setCollectorLocation]), `null` s'il n'en a pas.
  Future<ll.LatLng?> getCollectorLocation(String uid) async {
    final snap = await _collectorLocations.doc(uid).get();
    final lat = (snap.data()?['latitude'] as num?)?.toDouble();
    final lng = (snap.data()?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return ll.LatLng(lat, lng);
  }

  /// Compresse et enregistre la photo dans Firestore, renvoie la référence
  /// à stocker dans `imageUrl` de la demande. Lève [WastePhotoException].
  Future<String> uploadWastePhoto(String uid, File file) => _photos.upload(uid, file);

  /// Enregistre une photo déjà compressée (voir WastePhotoService.compress).
  Future<String> uploadCompressedWastePhoto(String uid, Uint8List jpeg) =>
      _photos.uploadCompressed(uid, jpeg);

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
    double? aiEstimatedWeightKg,
    String? aiDecision,
    required String address,
    required double latitude,
    required double longitude,
    required bool locationIsApproximate,
  }) async {
    // Quartier/ville du post (géocodage inverse OSM) : affichés dans la
    // notification et comparés aux zones des collecteurs. Jamais bloquant.
    ReverseGeocodeResult? place;
    try {
      place = await _geocoding.reverse(latitude, longitude).timeout(const Duration(seconds: 8));
    } catch (_) {
      place = null;
    }

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
      aiEstimatedWeightKg: aiEstimatedWeightKg,
      aiDecision: aiDecision,
      address: address,
      latitude: latitude,
      longitude: longitude,
      neighborhood: place?.neighborhood,
      city: place?.city,
      locationIsApproximate: locationIsApproximate,
      status: RequestStatus.pending,
      createdAt: DateTime.now(),
    );
    final docRef = await _requests.add(draft.toCreateMap());

    await _notifyQuietly(
      uid: householdUid,
      type: NotificationType.requestSubmitted,
      title: 'Demande envoyée',
      body: 'Votre demande de collecte a bien été enregistrée.',
      relatedRequestId: docRef.id,
    );

    final created = CollectionRequest.fromDoc(await docRef.get());
    await _notifyZoneCollectors(created);
    return created;
  }

  /// Notifie les Collecteurs dont AU MOINS UNE zone de collecte correspond
  /// au nouveau post — à [GeoConfig.zoneNotificationRadiusKm] ou moins, ou
  /// même quartier dans la même ville (voir [collectorsForPost]). Une seule
  /// notification par collecteur et par post, garantie par un identifiant
  /// fixe (`newpost_<id>`) : même relancé, il n'y a jamais de doublon.
  ///
  /// Uniquement les zones du profil : le GPS actuel du collecteur n'entre
  /// pas en compte ici (il sert à sa recherche manuelle "Autour de moi").
  /// Calculé sur l'appareil du Fournisseur (pas de Cloud Function sur le
  /// plan gratuit), jamais bloquant pour la création du post.
  Future<void> _notifyZoneCollectors(CollectionRequest post) async {
    try {
      final locations = await _collectorLocations.get();
      final matches = collectorsForPost(
        latitude: post.latitude,
        longitude: post.longitude,
        city: post.city,
        neighborhood: post.neighborhood,
        collectorLocations: {for (final d in locations.docs) d.id: d.data()},
      );
      final where = post.neighborhood ?? post.city;
      for (final m in matches) {
        final distance = m.distanceKm == null
            ? ''
            : ' · à ${m.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km de votre zone'
                '${m.zoneName.isEmpty ? '' : ' ${m.zoneName}'}';
        await _notifyQuietly(
          uid: m.collectorUid,
          id: 'newpost_${post.id}',
          type: NotificationType.newNearbyPost,
          title: 'Nouveau post disponible',
          body: '${post.category.label(true)} · ${post.quantityRange}'
              '${where == null ? '' : ' · $where'}$distance',
          relatedRequestId: post.id,
        );
      }
    } catch (_) {
      // Best-effort : une notification manquée n'empêche jamais la création
      // du post lui-même.
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
      await _notifyQuietly(
        uid: householdUid,
        type: NotificationType.requestAccepted,
        title: 'Collecteur assigné',
        body: '$collectorName a accepté votre demande de collecte.',
        relatedRequestId: requestId,
      );
    }
  }

  /// Le collecteur tape "Démarrer la collecte" (voir
  /// CollectorCollectionScreen) : horodaté sur la demande, et le Fournisseur
  /// est notifié pour partager sa position — le suivi en temps réel (voir
  /// LiveTrackingService) ne démarre de son côté qu'avec son accord.
  Future<void> startCollection(String requestId) async {
    final ref = _requests.doc(requestId);
    final request = CollectionRequest.fromDoc(await ref.get());
    if (request.status != RequestStatus.accepted) return;
    await ref.update({'collectionStartedAt': FieldValue.serverTimestamp()});
    await _notifyQuietly(
      uid: request.householdUid,
      type: NotificationType.statusChanged,
      title: 'Collecte démarrée 🚚',
      body: '${request.collectorName ?? 'Votre collecteur'} est en route. '
          'Partagez votre position pour le suivi en temps réel.',
      relatedRequestId: requestId,
    );
  }

  /// Le collecteur soumet poids + prix APRÈS la rencontre avec le
  /// fournisseur (demande explicite) — ni l'un ni l'autre ne sont
  /// définitifs tant que le fournisseur n'a pas scanné le QR et confirmé
  /// (voir [confirmCollectionResult]). [weightKg] doit être dans la
  /// tolérance autour du poids annoncé par le fournisseur à la création du
  /// post — vérifié ici en plus de l'UI (jamais confiance uniquement dans un
  /// contrôle client, voir [QuantityRangeBounds.acceptsCollectedWeight]).
  Future<void> submitCollectionResult(
    String requestId, {
    required double weightKg,
    required double priceFcfa,
  }) async {
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    final request = CollectionRequest.fromDoc(snap);

    if (!request.quantityRange.acceptsCollectedWeight(weightKg)) {
      throw const FormatException('weight-out-of-range');
    }
    if (priceFcfa <= 0) throw const FormatException('invalid-price');

    await ref.update({
      'status': RequestStatus.inProgress.name,
      'pendingWeightKg': weightKg,
      'pendingPriceFcfa': priceFcfa,
      'resultRejected': false,
      // Nouveau code à chaque formulaire : un QR d'un formulaire refusé ne
      // permet pas de confirmer le suivant.
      'scanCode': _newScanCode(),
    });

    await _notifyQuietly(
      uid: request.householdUid,
      type: NotificationType.statusChanged,
      title: 'Collecte à confirmer',
      body:
          '${request.collectorName ?? 'Le collecteur'} a soumis ${weightKg.toStringAsFixed(1)} kg '
          'pour ${priceFcfa.toStringAsFixed(0)} FCFA. Scannez son code pour confirmer.',
      relatedRequestId: requestId,
    );
  }

  /// Vérifie que [scanCode] est bien celui du QR affiché par le collecteur
  /// pour le formulaire en attente. Lève [StateError] (`invalid-scan`) sinon.
  CollectionRequest _requireScannedForm(
      DocumentSnapshot<Map<String, dynamic>> snap, String scanCode) {
    final request = CollectionRequest.fromDoc(snap);
    if (request.status != RequestStatus.inProgress ||
        request.scanCode == null ||
        request.scanCode != scanCode) {
      throw StateError('invalid-scan');
    }
    return request;
  }

  /// Le fournisseur a scanné le QR du collecteur (d'où [scanCode]) et
  /// accepte : poids/prix soumis deviennent définitifs, ses points sont
  /// calculés avec le barème de la page "Taux de conversion" et la
  /// commission du collecteur avec les tarifs de commission (voir
  /// [RewardsConfig]), à partir du poids réel — jamais du prix négocié, qui
  /// reste un paiement direct entre les deux parties. Écrit sur LA DEMANDE,
  /// jamais directement dans le portefeuille d'un autre (voir
  /// firestore.rules/[settleCompletedRequest]).
  Future<void> confirmCollectionResult(String requestId, {required String scanCode}) async {
    final ref = _requests.doc(requestId);
    final request = _requireScannedForm(await ref.get(), scanCode);
    final weight = request.pendingWeightKg;
    final price = request.pendingPriceFcfa;
    if (weight == null || price == null) throw StateError('invalid-scan');

    final points = RewardsConfig.pointsForCollection(request.category, weight).round();
    final commission = RewardsConfig.commissionForCollection(request.category, weight);

    await ref.update({
      'status': RequestStatus.completed.name,
      'weightKg': weight,
      'valueFcfa': price,
      'pointsEarned': points,
      'commissionFcfa': commission,
      'pendingWeightKg': null,
      'pendingPriceFcfa': null,
      'scanCode': null,
      'completedAt': FieldValue.serverTimestamp(),
    });

    // Crédite tout de suite les points du Fournisseur (c'est lui qui
    // exécute cette méthode, donc il écrit bien dans SON PROPRE portefeuille
    // — voir firestore.rules), puis arrête le suivi en temps réel.
    await settleCompletedRequest(
        CollectionRequest.fromDoc(await ref.get()), firestore: _firestore);
    await LiveTrackingService(firestore: _firestore).clear(requestId);

    if (request.collectorUid != null) {
      await _notifyQuietly(
        uid: request.collectorUid!,
        type: NotificationType.requestCompleted,
        title: 'Collecte confirmée ✅',
        body: 'Le fournisseur a confirmé la collecte : ${weight.toStringAsFixed(1)} kg. '
            'Commission : ${commission.toStringAsFixed(0)} FCFA.',
        relatedRequestId: requestId,
      );
    }
  }

  /// Le fournisseur a scanné le QR et refuse le poids/prix soumis — retour
  /// à [RequestStatus.accepted] ; le collecteur voit une erreur sur son
  /// écran Collecte et reçoit une notification pour renvoyer le formulaire.
  Future<void> rejectCollectionResult(String requestId, {required String scanCode}) async {
    final ref = _requests.doc(requestId);
    final request = _requireScannedForm(await ref.get(), scanCode);

    await ref.update({
      'status': RequestStatus.accepted.name,
      'pendingWeightKg': null,
      'pendingPriceFcfa': null,
      'scanCode': null,
      'resultRejected': true,
    });

    if (request.collectorUid != null) {
      await _notifyQuietly(
        uid: request.collectorUid!,
        type: NotificationType.collectionRejected,
        title: 'Collecte refusée',
        body: 'Le fournisseur a refusé le poids/prix soumis. Vérifiez et renvoyez le formulaire.',
        relatedRequestId: requestId,
      );
    }
  }

  static const _scanAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _random = Random.secure();
  static String _newScanCode() =>
      List.generate(10, (_) => _scanAlphabet[_random.nextInt(_scanAlphabet.length)]).join();

  /// Une notification ratée (réseau, règle) ne doit jamais faire échouer
  /// l'action métier qui vient de réussir — c'est ce qui laissait une
  /// confirmation à moitié faite.
  Future<void> _notifyQuietly({
    required String uid,
    required NotificationType type,
    required String title,
    required String body,
    String? relatedRequestId,
    String? id,
  }) async {
    try {
      await NotificationService(firestore: _firestore).notify(
          uid: uid, type: type, title: title, body: body, relatedRequestId: relatedRequestId, id: id);
    } catch (_) {}
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
