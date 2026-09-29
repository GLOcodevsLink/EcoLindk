import 'collection_request.dart';

/// Statistiques réelles d'un Fournisseur de déchets, calculées à partir de
/// TOUS ses posts (voir CollectionService.watchAllRequests) — aucune valeur
/// inventée : un jour sans collecte vaut 0 kg, un compte sans post affiche
/// des zéros.
class HouseholdStats {
  /// Collectes terminées (confirmées par le scan du QR).
  final int completedCount;

  /// Posts en attente d'un collecteur, acceptés ou en attente de confirmation.
  final int inProgressCount;
  final int cancelledCount;

  /// Poids total réellement collecté (kg confirmés), et points gagnés.
  final double totalKg;
  final int totalPoints;

  /// Kg collectés chacun des 7 derniers jours, du plus ancien à aujourd'hui.
  final List<DailyKg> last7Days;

  /// Kg collectés par catégorie (catégories sans collecte absentes), du plus
  /// gros au plus petit.
  final List<MapEntry<WasteCategory, double>> kgByCategory;

  const HouseholdStats({
    required this.completedCount,
    required this.inProgressCount,
    required this.cancelledCount,
    required this.totalKg,
    required this.totalPoints,
    required this.last7Days,
    required this.kgByCategory,
  });

  int get totalPosts => completedCount + inProgressCount + cancelledCount;

  /// Part des posts effectivement collectés (0..1), `0` sans post.
  double get completionRate => totalPosts == 0 ? 0 : completedCount / totalPosts;

  double get maxDailyKg => last7Days.fold(0, (m, d) => d.kg > m ? d.kg : m);

  factory HouseholdStats.from(List<CollectionRequest> requests, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final daily = {for (final d in days) d: 0.0};
    final byCategory = <WasteCategory, double>{};

    var completed = 0, inProgress = 0, cancelled = 0, points = 0;
    var kg = 0.0;
    for (final r in requests) {
      switch (r.status) {
        case RequestStatus.completed:
          completed++;
          final w = r.weightKg ?? 0;
          kg += w;
          points += r.pointsEarned ?? 0;
          byCategory[r.category] = (byCategory[r.category] ?? 0) + w;
          final at = r.completedAt;
          if (at != null) {
            final d = _day(at);
            if (daily.containsKey(d)) daily[d] = daily[d]! + w;
          }
        case RequestStatus.cancelled:
          cancelled++;
        case RequestStatus.pending || RequestStatus.accepted || RequestStatus.inProgress:
          inProgress++;
      }
    }

    final categories = byCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return HouseholdStats(
      completedCount: completed,
      inProgressCount: inProgress,
      cancelledCount: cancelled,
      totalKg: kg,
      totalPoints: points,
      last7Days: [for (final d in days) DailyKg(d, daily[d]!)],
      kgByCategory: categories,
    );
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}

class DailyKg {
  final DateTime day;
  final double kg;
  const DailyKg(this.day, this.kg);
}
