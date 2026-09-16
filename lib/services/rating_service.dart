import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/collection_rating.dart';

/// Une note par collecte terminée (`ratings/{requestId}`) — voir règle
/// métier #15/#22 : uniquement après une collecte "completed", jamais plus
/// d'une fois pour la même demande.
class RatingService {
  RatingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _firestore.collection('ratings');

  Future<CollectionRating?> fetch(String requestId) async {
    final doc = await _ratings.doc(requestId).get();
    return doc.exists ? CollectionRating.fromDoc(doc) : null;
  }

  Future<void> submit(CollectionRating rating) {
    return _ratings.doc(rating.requestId).set(rating.toCreateMap());
  }
}
