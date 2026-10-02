import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/models/household_stats.dart';
import 'package:flutter_test/flutter_test.dart';

CollectionRequest req(
  RequestStatus status, {
  WasteCategory category = WasteCategory.plastic,
  double? weightKg,
  int? points,
  DateTime? completedAt,
}) =>
    CollectionRequest(
      id: 'r${status.name}${completedAt?.millisecondsSinceEpoch ?? 0}',
      householdUid: 'house',
      householdName: 'Awa',
      imageUrl: '',
      description: '',
      category: category,
      quantityRange: '5 kg',
      aiRequested: false,
      address: '',
      latitude: 0,
      longitude: 0,
      locationIsApproximate: false,
      status: status,
      weightKg: weightKg,
      pointsEarned: points,
      createdAt: DateTime(2026, 9, 1),
      completedAt: completedAt,
    );

void main() {
  final now = DateTime(2026, 9, 29, 15); // mardi

  test('no post → only zeros, never made-up values', () {
    final s = HouseholdStats.from(const [], now: now);
    expect(s.totalPosts, 0);
    expect(s.completionRate, 0);
    expect(s.totalKg, 0);
    expect(s.last7Days, hasLength(7));
    expect(s.last7Days.every((d) => d.kg == 0), isTrue);
    expect(s.kgByCategory, isEmpty);
  });

  test('counts posts by real status and sums confirmed kg and points', () {
    final s = HouseholdStats.from([
      req(RequestStatus.completed, weightKg: 11, points: 33, completedAt: DateTime(2026, 9, 29, 9)),
      req(RequestStatus.completed,
          category: WasteCategory.metal, weightKg: 2, points: 12, completedAt: DateTime(2026, 9, 27, 18)),
      req(RequestStatus.pending),
      req(RequestStatus.accepted),
      req(RequestStatus.inProgress),
      req(RequestStatus.cancelled),
    ], now: now);

    expect(s.completedCount, 2);
    expect(s.inProgressCount, 3);
    expect(s.cancelledCount, 1);
    expect(s.totalKg, 13);
    expect(s.totalPoints, 45);
    expect(s.completionRate, closeTo(2 / 6, 1e-9));
    expect(s.kgByCategory.map((e) => e.key), [WasteCategory.plastic, WasteCategory.metal]);
  });

  test('last 7 days: kg on the right day, today last', () {
    final s = HouseholdStats.from([
      req(RequestStatus.completed, weightKg: 4, completedAt: DateTime(2026, 9, 29, 8)),
      req(RequestStatus.completed, weightKg: 1.5, completedAt: DateTime(2026, 9, 29, 20)),
      req(RequestStatus.completed, weightKg: 3, completedAt: DateTime(2026, 9, 23, 10)), // il y a 6 jours
      req(RequestStatus.completed, weightKg: 9, completedAt: DateTime(2026, 9, 20)), // trop ancien
    ], now: now);

    expect(s.last7Days.first.day, DateTime(2026, 9, 23));
    expect(s.last7Days.last.day, DateTime(2026, 9, 29));
    expect(s.last7Days.first.kg, 3);
    expect(s.last7Days.last.kg, 5.5);
    expect(s.last7Days.map((d) => d.kg).reduce((a, b) => a + b), 8.5);
    expect(s.maxDailyKg, 5.5);
    // Le total global compte aussi les collectes plus anciennes.
    expect(s.totalKg, 17.5);
  });
}
