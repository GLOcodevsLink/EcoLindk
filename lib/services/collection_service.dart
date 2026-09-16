import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/rewards_config.dart';
import '../models/app_notification.dart';
import '../models/collection_request.dart';
import 'notification_service.dart';
import 'referral_service.dart';
import 'wallet_service.dart';

/// CRUD + logique métier des demandes de collecte (`collectionRequests/{id}`
/// dans Firestore, photo dans Firebase Storage sous `waste_photos/{uid}/…`).
///
/// Ce service porte aussi les actions "côté Collecteur" ([acceptRequest],
/// [completeRequest]) même si l'écran Collecteur correspondant n'est pas
/// encore construit (ce sera la prochaine étape) : la logique et les règles
/// de sécurité (une seule acceptation possible, voir [acceptRequest]) sont
/// déjà correctes et prêtes à être appelées par ces futurs écrans.
class CollectionService {
  CollectionService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('collectionRequests');

  Future<String> uploadWastePhoto(String uid, File file) async {
    final ref = _storage.ref(
        'waste_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

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

    await NotificationService().notify(
      uid: householdUid,
      type: NotificationType.requestSubmitted,
      title: 'Demande envoyée',
      body: 'Votre demande de collecte a bien été enregistrée.',
      relatedRequestId: docRef.id,
    );

    final snap = await docRef.get();
    return CollectionRequest.fromDoc(snap);
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
      await NotificationService().notify(
        uid: householdUid,
        type: NotificationType.requestAccepted,
        title: 'Collecteur assigné',
        body: '$collectorName a accepté votre demande de collecte.',
        relatedRequestId: requestId,
      );
    }
  }

  Future<void> updateStatus(String requestId, RequestStatus status) async {
    await _requests.doc(requestId).update({'status': status.name});
    final snap = await _requests.doc(requestId).get();
    final householdUid = snap.data()?['householdUid'] as String?;
    if (householdUid != null) {
      await NotificationService().notify(
        uid: householdUid,
        type: NotificationType.statusChanged,
        title: 'Statut mis à jour',
        body: 'Votre collecte est maintenant : ${status.label(true)}.',
        relatedRequestId: requestId,
      );
    }
  }

  /// Le collecteur pèse le déchet -> points/valeur calculés depuis le
  /// barème unique [RewardsConfig] et écrits sur LA DEMANDE (jamais
  /// directement dans le portefeuille du Fournisseur — voir firestore.rules
  /// et [settleCompletedRequest] : c'est le Fournisseur lui-même qui réclame
  /// ensuite ces points dans son propre portefeuille). Génère aussi la trace
  /// de traçabilité (les champs de [CollectionRequest] complétée eux-mêmes
  /// en tiennent lieu — voir [CollectionRequest.reference]).
  Future<void> completeRequest(String requestId, {required double weightKg}) async {
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    final request = CollectionRequest.fromDoc(snap);

    final points = RewardsConfig.pointsForCollection(request.category, weightKg).round();
    final value = RewardsConfig.valueForCollection(request.category, weightKg);

    await ref.update({
      'status': RequestStatus.completed.name,
      'weightKg': weightKg,
      'valueFcfa': value,
      'pointsEarned': points,
      'completedAt': FieldValue.serverTimestamp(),
    });

    await NotificationService().notify(
      uid: request.householdUid,
      type: NotificationType.requestCompleted,
      title: 'Collecte terminée ✅',
      body: '${weightKg.toStringAsFixed(1)} kg collectés.',
      relatedRequestId: requestId,
    );
  }
}

/// À appeler côté client du Fournisseur de déchets chaque fois qu'une de ses
/// demandes complétées lui est affichée (voir RequestStatusScreen,
/// CollectionHistoryScreen, CollectionDetailScreen) : réclame ses propres
/// points dans son propre portefeuille et tente de qualifier son parrainage
/// — les deux opérations n'écrivent jamais que les données du Fournisseur
/// lui-même (voir firestore.rules) et sont sans danger à rappeler plusieurs
/// fois (idempotentes).
Future<void> settleCompletedRequest(CollectionRequest request) async {
  if (request.status != RequestStatus.completed) return;
  await WalletService().claimCollectionPoints(request);
  await ReferralService()
      .creditIfQualifying(uid: request.householdUid, weightKg: request.weightKg ?? 0);
}
