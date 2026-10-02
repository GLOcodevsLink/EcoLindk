import 'package:ecolindk/admin/models/admin_models.dart';
import 'package:ecolindk/admin/services/admin_stats.dart';
import 'package:ecolindk/models/collection_rating.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/models/user_role.dart';
import 'package:ecolindk/models/wallet_models.dart';
import 'package:ecolindk/services/commission_service.dart';
import 'package:flutter_test/flutter_test.dart';

CollectionRequest req(
  String id, {
  RequestStatus status = RequestStatus.completed,
  WasteCategory category = WasteCategory.plastic,
  String household = 'h1',
  String? collector = 'c1',
  double? weight = 4,
  double? value = 300,
  int? points = 12,
  double? commission,
  DateTime? createdAt,
}) =>
    CollectionRequest(
      id: id,
      householdUid: household,
      householdName: 'Awa',
      imageUrl: '',
      description: '',
      category: category,
      quantityRange: '4 kg',
      aiRequested: false,
      address: '',
      latitude: 0,
      longitude: 0,
      locationIsApproximate: false,
      status: status,
      collectorUid: collector,
      weightKg: status == RequestStatus.completed ? weight : null,
      valueFcfa: status == RequestStatus.completed ? value : null,
      pointsEarned: status == RequestStatus.completed ? points : null,
      commissionFcfa: commission,
      createdAt: createdAt ?? DateTime(2026, 9, 30, 10),
    );

AdminUser user(String uid, UserRole? role) =>
    AdminUser(uid: uid, fullName: uid, email: '$uid@x.cm', phone: '', address: '', role: role);

CommissionPayment pay(String collector, int amount, String status) => CommissionPayment(
      id: '$collector$amount$status',
      collectorUid: collector,
      amountFcfa: amount,
      phone: '',
      channel: 'cm.mtn',
      mode: 'Simulation',
      status: status,
      createdAt: DateTime(2026, 9, 30),
    );

void main() {
  final now = DateTime(2026, 10, 1, 15);

  AdminStats compute({
    List<AdminUser> users = const [],
    List<CollectionRequest> requests = const [],
    List<CommissionPayment> payments = const [],
    List<AdminRedemption> redemptions = const [],
  }) =>
      AdminStats.compute(
        users: users,
        requests: requests,
        commissionPayments: payments,
        redemptions: redemptions,
        wallets: const {},
        now: now,
      );

  test('counts users by role, incomplete registrations apart', () {
    final st = compute(users: [
      user('a', UserRole.household),
      user('b', UserRole.household),
      user('c', UserRole.collector),
      user('d', null),
    ]);
    expect(st.providers, 2);
    expect(st.collectors, 1);
    expect(st.incompleteAccounts, 1);
  });

  test('sums weight, value, points and kg per category from completed collections only', () {
    final st = compute(requests: [
      req('1', weight: 4, value: 300, points: 12),
      req('2', category: WasteCategory.glass, weight: 2, value: 100, points: 1),
      req('3', status: RequestStatus.pending),
      req('4', status: RequestStatus.cancelled),
    ]);
    expect(st.totalRequests, 4);
    expect(st.count(RequestStatus.completed), 2);
    expect(st.count(RequestStatus.pending), 1);
    expect(st.kgCollected, 6);
    expect(st.valueFcfa, 400);
    expect(st.pointsAwarded, 13);
    expect(st.kgByCategory, {WasteCategory.plastic: 4.0, WasteCategory.glass: 2.0});
    // 2 terminées sur 3 posts clos (terminés + annulés).
    expect(st.completionRatePct, 67);
  });

  test('commission outstanding follows CommissionService: due minus successful payments', () {
    final st = compute(
      requests: [req('1', commission: 500), req('2', weight: 3)], // 2nd : 3 kg × 10 FCFA (plastique)
      payments: [pay('c1', 200, 'success'), pay('c1', 1000, 'failed'), pay('c1', 50, 'pending')],
    );
    expect(st.commissionDueFcfa, 530);
    expect(st.commissionPaidFcfa, 200);
    expect(st.commissionOutstandingFcfa, 330);
    expect(st.failedPayments, 1);
    expect(st.pendingPayments, 1);
  });

  test('outstanding never goes negative when collectors overpay', () {
    final st = compute(requests: [req('1', commission: 100)], payments: [pay('c1', 500, 'success')]);
    expect(st.commissionOutstandingFcfa, 0);
  });

  test('posts per day covers the last 14 days, today included, oldest first', () {
    final st = compute(requests: [
      req('1', createdAt: DateTime(2026, 10, 1, 8)),
      req('2', createdAt: DateTime(2026, 10, 1, 23)),
      req('3', createdAt: DateTime(2026, 9, 18)), // premier jour de la fenêtre
      req('4', createdAt: DateTime(2026, 9, 17)), // hors fenêtre
    ]);
    expect(st.postsPerDay, hasLength(14));
    expect(st.postsPerDay.first.day, DateTime(2026, 9, 18));
    expect(st.postsPerDay.first.count, 1);
    expect(st.postsPerDay.last.day, DateTime(2026, 10, 1));
    expect(st.postsPerDay.last.count, 2);
    expect(st.postsPerDay.fold<int>(0, (t, p) => t + p.count), 3);
  });

  test('redeemed total only counts completed conversions', () {
    RedemptionRequest r(double amount, RedemptionStatus status) => RedemptionRequest(
          id: '$amount',
          method: RedemptionMethod.airtime,
          pointsSpent: 15,
          amountFcfa: amount,
          recipientPhone: '',
          status: status,
          createdAt: DateTime(2026),
        );
    final st = compute(redemptions: [
      AdminRedemption('h1', r(500, RedemptionStatus.completed)),
      AdminRedemption('h1', r(1000, RedemptionStatus.pending)),
    ]);
    expect(st.redeemedFcfa, 500);
  });

  group('per-user summaries', () {
    test('ProviderSummary counts only that provider and reads their wallet', () {
      final sum = ProviderSummary.of(
        'h1',
        [req('1'), req('2', status: RequestStatus.pending), req('3', household: 'h2')],
        {'h1': const WalletSummary(balance: 40, lifetimeEarned: 90)},
      );
      expect(sum.posts, 2);
      expect(sum.completed, 1);
      expect(sum.kg, 4);
      expect(sum.wallet.balance, 40);
    });

    test('CollectorSummary computes outstanding commission and average rating', () {
      CollectionRating rating(String id, int stars, String collector) => CollectionRating(
          requestId: id, householdUid: 'h1', collectorUid: collector, stars: stars, comment: '', createdAt: DateTime(2026));
      final sum = CollectorSummary.of(
        'c1',
        [req('1', commission: 300), req('2', status: RequestStatus.accepted), req('3', collector: 'c2', commission: 999)],
        [pay('c1', 100, 'success'), pay('c2', 999, 'success')],
        [rating('1', 5, 'c1'), rating('x', 4, 'c1'), rating('y', 1, 'c2')],
      );
      expect(sum.accepted, 2);
      expect(sum.completed, 1);
      expect(sum.outstandingFcfa, 200);
      expect(sum.averageRating, 4.5);
      expect(sum.ratingCount, 2);
    });
  });
}
