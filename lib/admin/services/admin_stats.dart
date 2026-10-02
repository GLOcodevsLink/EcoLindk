import '../../models/collection_rating.dart';
import '../../models/collection_request.dart';
import '../../models/user_role.dart';
import '../../models/wallet_models.dart';
import '../../services/commission_service.dart';
import '../../services/payment_gateway.dart';
import '../models/admin_models.dart';

/// Chiffres globaux de la plateforme, calculés à partir des données déjà
/// lues (aucune lecture Firestore ici — testable avec de simples listes).
/// Les commissions reprennent exactement les règles de CommissionService.
class AdminStats {
  final int providers;
  final int collectors;

  /// Comptes créés dont l'inscription n'a jamais été terminée (pas de rôle).
  final int incompleteAccounts;

  final Map<RequestStatus, int> requestsByStatus;
  final int totalRequests;
  final double kgCollected;
  final double valueFcfa;
  final int pointsAwarded;
  final Map<WasteCategory, double> kgByCategory;

  final int commissionDueFcfa;
  final int commissionPaidFcfa;
  final int commissionOutstandingFcfa;
  final int failedPayments;
  final int pendingPayments;
  final double redeemedFcfa;

  /// Posts publiés par jour, du plus ancien au plus récent (14 jours, jour
  /// courant inclus).
  final List<({DateTime day, int count})> postsPerDay;

  const AdminStats({
    required this.providers,
    required this.collectors,
    required this.incompleteAccounts,
    required this.requestsByStatus,
    required this.totalRequests,
    required this.kgCollected,
    required this.valueFcfa,
    required this.pointsAwarded,
    required this.kgByCategory,
    required this.commissionDueFcfa,
    required this.commissionPaidFcfa,
    required this.commissionOutstandingFcfa,
    required this.failedPayments,
    required this.pendingPayments,
    required this.redeemedFcfa,
    required this.postsPerDay,
  });

  int count(RequestStatus status) => requestsByStatus[status] ?? 0;

  /// Part des posts menés jusqu'au bout, hors posts encore en cours.
  int get completionRatePct {
    final finished = count(RequestStatus.completed) + count(RequestStatus.cancelled);
    return finished == 0 ? 0 : (count(RequestStatus.completed) * 100 / finished).round();
  }

  static const chartDays = 14;

  factory AdminStats.compute({
    required List<AdminUser> users,
    required List<CollectionRequest> requests,
    required List<CommissionPayment> commissionPayments,
    required List<AdminRedemption> redemptions,
    required Map<String, WalletSummary> wallets,
    required DateTime now,
  }) {
    final byStatus = <RequestStatus, int>{};
    final kgByCategory = <WasteCategory, double>{};
    var kg = 0.0, value = 0.0, due = 0.0;
    var points = 0;
    for (final r in requests) {
      byStatus[r.status] = (byStatus[r.status] ?? 0) + 1;
      if (r.status != RequestStatus.completed) continue;
      final w = r.weightKg ?? 0;
      kg += w;
      kgByCategory[r.category] = (kgByCategory[r.category] ?? 0) + w;
      value += r.valueFcfa ?? 0;
      points += r.pointsEarned ?? 0;
      due += CommissionService.commissionOf(r);
    }

    final paid = commissionPayments.where((p) => p.isSuccess).fold<int>(0, (t, p) => t + p.amountFcfa);

    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = chartDays - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    final perDay = {for (final d in days) d: 0};
    for (final r in requests) {
      final d = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
      if (perDay.containsKey(d)) perDay[d] = perDay[d]! + 1;
    }

    return AdminStats(
      providers: users.where((u) => u.role == UserRole.household).length,
      collectors: users.where((u) => u.role == UserRole.collector).length,
      incompleteAccounts: users.where((u) => u.role == null).length,
      requestsByStatus: byStatus,
      totalRequests: requests.length,
      kgCollected: kg,
      valueFcfa: value,
      pointsAwarded: points,
      kgByCategory: kgByCategory,
      commissionDueFcfa: due.round(),
      commissionPaidFcfa: paid,
      commissionOutstandingFcfa: (due.round() - paid).clamp(0, 1 << 62),
      failedPayments: commissionPayments.where((p) => !p.isSuccess && !p.isPending).length,
      pendingPayments: commissionPayments.where((p) => p.isPending).length,
      redeemedFcfa: redemptions
          .where((r) => r.request.status == RedemptionStatus.completed)
          .fold<double>(0, (t, r) => t + r.request.amountFcfa),
      postsPerDay: [for (final d in days) (day: d, count: perDay[d]!)],
    );
  }
}

/// Activité d'un Fournisseur.
class ProviderSummary {
  final int posts;
  final int completed;
  final double kg;
  final WalletSummary wallet;

  const ProviderSummary({required this.posts, required this.completed, required this.kg, required this.wallet});

  factory ProviderSummary.of(String uid, List<CollectionRequest> requests, Map<String, WalletSummary> wallets) {
    final mine = requests.where((r) => r.householdUid == uid);
    final done = mine.where((r) => r.status == RequestStatus.completed);
    return ProviderSummary(
      posts: mine.length,
      completed: done.length,
      kg: done.fold(0, (t, r) => t + (r.weightKg ?? 0)),
      wallet: wallets[uid] ?? WalletSummary.empty,
    );
  }
}

/// Activité d'un Collecteur — solde de commission calculé par
/// CommissionService.outstanding, comme dans son écran Commission.
class CollectorSummary {
  final int accepted;
  final int completed;
  final double kg;
  final int outstandingFcfa;
  final double? averageRating;
  final int ratingCount;

  const CollectorSummary({
    required this.accepted,
    required this.completed,
    required this.kg,
    required this.outstandingFcfa,
    required this.averageRating,
    required this.ratingCount,
  });

  factory CollectorSummary.of(
    String uid,
    List<CollectionRequest> requests,
    List<CommissionPayment> payments,
    List<CollectionRating> ratings,
  ) {
    final mine = requests.where((r) => r.collectorUid == uid).toList();
    final done = mine.where((r) => r.status == RequestStatus.completed);
    final stars = ratings.where((r) => r.collectorUid == uid && r.stars > 0).map((r) => r.stars).toList();
    return CollectorSummary(
      accepted: mine.length,
      completed: done.length,
      kg: done.fold(0, (t, r) => t + (r.weightKg ?? 0)),
      outstandingFcfa:
          CommissionService.outstanding(mine, payments.where((p) => p.collectorUid == uid).toList()),
      averageRating: stars.isEmpty ? null : stars.reduce((a, b) => a + b) / stars.length,
      ratingCount: stars.length,
    );
  }
}

/// Libellé court d'un opérateur Mobile Money à partir de son `channel`.
String operatorLabel(String channel) =>
    MobileMoneyOperator.values.where((o) => o.channel == channel).firstOrNull?.label ?? channel;
