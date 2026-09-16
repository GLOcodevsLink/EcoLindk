import 'package:cloud_firestore/cloud_firestore.dart';

/// Origine/nature d'un mouvement de points (voir `wallets/{uid}/transactions`).
enum PointsTxType { earnedCollection, earnedReferral, redeemed, adjustment }

class PointsTransaction {
  final String id;
  final PointsTxType type;
  final int points; // positif = crédit, négatif = débit (redeemed)
  final String label;
  final String? relatedRequestId;
  final DateTime createdAt;

  const PointsTransaction({
    required this.id,
    required this.type,
    required this.points,
    required this.label,
    this.relatedRequestId,
    required this.createdAt,
  });

  factory PointsTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PointsTransaction(
      id: doc.id,
      type: PointsTxType.values.firstWhere(
          (t) => t.name == d['type'], orElse: () => PointsTxType.adjustment),
      points: (d['points'] as num?)?.toInt() ?? 0,
      label: d['label'] as String? ?? '',
      relatedRequestId: d['relatedRequestId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Moyens de conversion des points en valeur réelle — voir RewardsConfig
/// pour le taux, et RedeemScreen pour le flux de sélection.
enum RedemptionMethod { airtime, mobileData, withdrawal, sendToRelative }

enum RedemptionStatus { pending, completed }

class RedemptionRequest {
  final String id;
  final RedemptionMethod method;
  final int pointsSpent;
  final double amountFcfa;
  final String recipientPhone; // numéro crédité (soi-même ou un proche)
  final RedemptionStatus status;
  final DateTime createdAt;

  const RedemptionRequest({
    required this.id,
    required this.method,
    required this.pointsSpent,
    required this.amountFcfa,
    required this.recipientPhone,
    required this.status,
    required this.createdAt,
  });

  factory RedemptionRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return RedemptionRequest(
      id: doc.id,
      method: RedemptionMethod.values.firstWhere(
          (m) => m.name == d['method'], orElse: () => RedemptionMethod.withdrawal),
      pointsSpent: (d['pointsSpent'] as num?)?.toInt() ?? 0,
      amountFcfa: (d['amountFcfa'] as num?)?.toDouble() ?? 0,
      recipientPhone: d['recipientPhone'] as String? ?? '',
      status: RedemptionStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => RedemptionStatus.pending),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
