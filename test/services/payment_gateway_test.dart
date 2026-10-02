import 'dart:convert';
import 'package:ecolindk/services/payment_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SimulatedPaymentGateway', () {
    test('follows the Notch Pay test-number outcomes', () {
      expect(SimulatedPaymentGateway.outcomeFor('+237670000000'), PaymentStatus.success);
      expect(SimulatedPaymentGateway.outcomeFor('+237670000001'), PaymentStatus.insufficientFunds);
      expect(SimulatedPaymentGateway.outcomeFor('+237690000002'), PaymentStatus.failed);
      expect(SimulatedPaymentGateway.outcomeFor('+237670000003'), PaymentStatus.timeout);
      expect(SimulatedPaymentGateway.outcomeFor('+237670000004'), PaymentStatus.canceled);
      expect(SimulatedPaymentGateway.outcomeFor('+237650123456'), PaymentStatus.success);
    });

    test('collect returns the outcome with the reference', () async {
      final r = await SimulatedPaymentGateway(delay: Duration.zero).collect(
          amountFcfa: 500,
          phone: '+237670000001',
          operator: MobileMoneyOperator.mtn,
          reference: 'ref1',
          description: 'test');
      expect(r.status, PaymentStatus.insufficientFunds);
      expect(r.reference, 'ref1');
    });
  });

  group('NotchPaySandboxGateway', () {
    Future<PaymentResult> collect(NotchPaySandboxGateway g) => g.collect(
        amountFcfa: 500,
        phone: '+237670000000',
        operator: MobileMoneyOperator.orange,
        reference: 'ecl_com_x',
        description: 'Commission');

    test('refuses a key that is not a test key', () {
      final g = NotchPaySandboxGateway(publicKey: 'pk_live_abc');
      expect(() => collect(g), throwsStateError);
    });

    test('initializes, charges the channel, then polls until complete', () async {
      final calls = <String>[];
      var polls = 0;
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        expect(req.headers['Authorization'], 'pk_test.abc');
        if (req.method == 'POST') {
          final body = jsonDecode(req.body) as Map;
          expect(body['amount'], 500);
          expect(body['currency'], 'XAF');
          expect(body['reference'], 'ecl_com_x');
          return http.Response('{"code":201,"transaction":{"reference":"trx.test_1","status":"pending"}}', 201);
        }
        if (req.method == 'PUT') {
          final body = jsonDecode(req.body) as Map;
          expect(body['channel'], 'cm.orange');
          expect(body['data']['phone'], '237670000000');
          return http.Response('{"code":202}', 202);
        }
        polls++;
        final status = polls < 2 ? 'pending' : 'complete';
        return http.Response('{"transaction":{"status":"$status"}}', 200);
      });
      final g = NotchPaySandboxGateway(
          publicKey: 'pk_test.abc', client: client, pollInterval: Duration.zero);

      final r = await collect(g);
      expect(r.status, PaymentStatus.success);
      expect(calls, [
        'POST /payments',
        'PUT /payments/trx.test_1',
        'GET /payments/trx.test_1',
        'GET /payments/trx.test_1',
      ]);
    });

    test('reports the API message when initialization is refused', () async {
      final client = MockClient((_) async => http.Response('{"message":"Unauthorized"}', 401));
      final g = NotchPaySandboxGateway(publicKey: 'pk_test_bad', client: client);
      final r = await collect(g);
      expect(r.status, PaymentStatus.failed);
      expect(r.message, 'Unauthorized');
    });

    test('statusOf maps final states and waits on pending ones', () {
      String body(String s) => '{"transaction":{"status":"$s"}}';
      expect(NotchPaySandboxGateway.statusOf(body('complete')), PaymentStatus.success);
      expect(NotchPaySandboxGateway.statusOf(body('failed')), PaymentStatus.failed);
      expect(NotchPaySandboxGateway.statusOf(body('canceled')), PaymentStatus.canceled);
      expect(NotchPaySandboxGateway.statusOf(body('expired')), PaymentStatus.timeout);
      expect(NotchPaySandboxGateway.statusOf(body('pending')), isNull);
      expect(NotchPaySandboxGateway.statusOf('not json'), isNull);
    });
  });
}
