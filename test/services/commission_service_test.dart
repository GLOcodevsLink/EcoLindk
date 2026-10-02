import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/services/commission_service.dart';
import 'package:ecolindk/services/payment_gateway.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CommissionService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = CommissionService(
        firestore: db, gateway: SimulatedPaymentGateway(delay: Duration.zero));
  });

  CollectionRequest request({double? commission, RequestStatus status = RequestStatus.completed}) =>
      CollectionRequest(
        id: 'r',
        householdUid: 'house',
        householdName: 'Awa',
        imageUrl: '',
        description: '',
        category: WasteCategory.plastic,
        quantityRange: '4 kg',
        aiRequested: false,
        address: '',
        latitude: 0,
        longitude: 0,
        locationIsApproximate: false,
        status: status,
        weightKg: 4,
        commissionFcfa: commission,
        createdAt: DateTime(2026),
      );

  CommissionPayment payment(int amount, String status) => CommissionPayment(
        id: 'p',
        collectorUid: 'c',
        amountFcfa: amount,
        phone: '',
        channel: 'cm.mtn',
        mode: 'Simulation',
        status: status,
        createdAt: DateTime(2026),
      );

  group('outstanding', () {
    test('sums completed commissions, minus successful payments only', () {
      final history = [
        request(commission: 300),
        request(commission: 200),
        request(commission: 999, status: RequestStatus.cancelled),
      ];
      final payments = [payment(150, 'success'), payment(100, 'failed'), payment(50, 'pending')];
      expect(CommissionService.outstanding(history, payments), 350);
    });

    test('falls back to weight × rate when the commission was not stored', () {
      // Plastique : 10 FCFA/kg × 4 kg.
      expect(CommissionService.outstanding([request()], const []), 40);
    });

    test('never goes below zero', () {
      expect(CommissionService.outstanding([request(commission: 100)], [payment(500, 'success')]), 0);
    });
  });

  group('payCommission', () {
    Future<Map<String, dynamic>> onlyDoc() async =>
        (await db.collection('commissionPayments').get()).docs.single.data();

    test('records a successful payment', () async {
      final r = await service.payCommission(
          collectorUid: 'c', amountFcfa: 350, phone: '+237670000000', operator: MobileMoneyOperator.mtn);
      expect(r.isSuccess, isTrue);
      final d = await onlyDoc();
      expect(d['status'], 'success');
      expect(d['amountFcfa'], 350);
      expect(d['channel'], 'cm.mtn');
      expect(d['reference'], startsWith('ecl_com_'));
      final payments = await service.watchPayments('c').first;
      expect(CommissionService.outstanding([request(commission: 350)], payments), 0);
    });

    test('records a failed payment without reducing what is owed', () async {
      final r = await service.payCommission(
          collectorUid: 'c', amountFcfa: 350, phone: '+237670000001', operator: MobileMoneyOperator.mtn);
      expect(r.status, PaymentStatus.insufficientFunds);
      expect((await onlyDoc())['status'], 'insufficientFunds');
      final payments = await service.watchPayments('c').first;
      expect(CommissionService.outstanding([request(commission: 350)], payments), 350);
    });

    test('marks the payment failed if the gateway throws', () async {
      final s = CommissionService(
          firestore: db, gateway: NotchPaySandboxGateway(publicKey: 'missing'));
      final r = await s.payCommission(
          collectorUid: 'c', amountFcfa: 100, phone: '+237670000000', operator: MobileMoneyOperator.mtn);
      expect(r.status, PaymentStatus.failed);
      expect((await onlyDoc())['status'], 'failed');
    });
  });
}
