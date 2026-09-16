import 'package:cloud_firestore/cloud_firestore.dart';

enum ReferralStatus { pending, qualified }

/// Un filleul parrainé, stocké dans `referrals/{referrerUid}/uses/{referredUid}`.
/// Créé (status `pending`) à l'inscription du filleul via son code, puis
/// passé à `qualified` (et seulement à ce moment les points sont crédités —
/// voir ReferralService.creditIfQualifying) dès que ce filleul termine sa
/// première collecte qualifiante. Ne peut être crédité qu'une seule fois.
class ReferralUse {
  final String referredUid;
  final String referredName;
  final ReferralStatus status;
  final int pointsAwarded;
  final DateTime createdAt;
  final DateTime? qualifiedAt;

  const ReferralUse({
    required this.referredUid,
    required this.referredName,
    required this.status,
    required this.pointsAwarded,
    required this.createdAt,
    this.qualifiedAt,
  });

  factory ReferralUse.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ReferralUse(
      referredUid: doc.id,
      referredName: d['referredName'] as String? ?? '',
      status: ReferralStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => ReferralStatus.pending),
      pointsAwarded: (d['pointsAwarded'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      qualifiedAt: (d['qualifiedAt'] as Timestamp?)?.toDate(),
    );
  }
}
