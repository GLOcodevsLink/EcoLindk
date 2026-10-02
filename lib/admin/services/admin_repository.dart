import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/collection_rating.dart';
import '../../models/collection_request.dart';
import '../../services/commission_service.dart';
import '../models/admin_models.dart';

/// Lecture des collections Firestore pour le tableau de bord, avec les
/// modèles de l'app mobile (CollectionRequest, CommissionPayment,
/// CollectionRating…). Les droits viennent de `isAdmin()` dans
/// firestore.rules : sans document `admins/{uid}`, chaque flux échoue en
/// `permission-denied`.
///
/// Les tris sont faits localement (comme dans CommissionService) pour ne
/// demander aucun index composite. Chaque flux lit TOUTE sa collection :
/// adapté au volume actuel ; au-delà de quelques milliers de documents,
/// paginer ou passer par des agrégats (`count()`/`sum()`).
class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests => _firestore.collection('collectionRequests');

  /// L'utilisateur connecté figure-t-il dans `admins/` ?
  Future<bool> isAdmin(String uid) async => (await _firestore.collection('admins').doc(uid).get()).exists;

  Stream<List<AdminUser>> watchUsers() => _firestore
      .collection('users')
      .snapshots()
      .map((q) => q.docs.map(AdminUser.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));

  Stream<List<CollectionRequest>> watchRequests() => _requests
      .snapshots()
      .map((q) => q.docs.map(CollectionRequest.fromDoc).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Stream<List<CommissionPayment>> watchCommissionPayments() => _firestore
      .collection('commissionPayments')
      .snapshots()
      .map((q) => q.docs.map(CommissionPayment.fromDoc).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// Conversions de points de tous les Fournisseurs (collectionGroup).
  Stream<List<AdminRedemption>> watchRedemptions() => _firestore
      .collectionGroup('redemptions')
      .snapshots()
      .map((q) => q.docs.map(AdminRedemption.fromDoc).toList()
        ..sort((a, b) => b.request.createdAt.compareTo(a.request.createdAt)));

  Stream<Map<String, WalletSummary>> watchWallets() => _firestore
      .collection('wallets')
      .snapshots()
      .map((q) => {for (final d in q.docs) d.id: WalletSummary.fromData(d.data())});

  Stream<List<CollectionRating>> watchRatings() =>
      _firestore.collection('ratings').snapshots().map((q) => q.docs.map(CollectionRating.fromDoc).toList());

  /// Retire un post encore libre (modération) : même passage à `cancelled`
  /// que l'annulation par son Fournisseur, marqué `cancelledByAdmin`. En
  /// transaction : si un collecteur l'a accepté entre-temps, rien n'est
  /// écrit et une [StateError] est levée.
  Future<void> cancelPost(String requestId) => _firestore.runTransaction((tx) async {
        final ref = _requests.doc(requestId);
        final snap = await tx.get(ref);
        if (snap.data()?['status'] != RequestStatus.pending.name) {
          throw StateError('not-pending');
        }
        tx.update(ref, {'status': RequestStatus.cancelled.name, 'cancelledByAdmin': true});
      });
}
