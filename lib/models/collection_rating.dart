import 'package:cloud_firestore/cloud_firestore.dart';

/// Note laissée par le Fournisseur de déchets à propos du Collecteur, une
/// fois la collecte `completed` — stockée dans `ratings/{requestId}` (une
/// seule note par collecte, voir règle métier).
class CollectionRating {
  final String requestId;
  final String householdUid;
  final String collectorUid;
  final int stars; // 1-5
  final String comment;
  final DateTime createdAt;

  const CollectionRating({
    required this.requestId,
    required this.householdUid,
    required this.collectorUid,
    required this.stars,
    required this.comment,
    required this.createdAt,
  });

  factory CollectionRating.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CollectionRating(
      requestId: doc.id,
      householdUid: d['householdUid'] as String? ?? '',
      collectorUid: d['collectorUid'] as String? ?? '',
      stars: (d['stars'] as num?)?.toInt() ?? 0,
      comment: d['comment'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'householdUid': householdUid,
        'collectorUid': collectorUid,
        'stars': stars,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
