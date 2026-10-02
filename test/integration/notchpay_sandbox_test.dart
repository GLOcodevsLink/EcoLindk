// Real calls to the Notch Pay sandbox (no real money). Skipped unless the
// test key is in the environment:
//   NOTCH_API_KEY=$(grep ^NOTCH_API_KEY= .env | cut -d= -f2-) flutter test test/integration
import 'dart:io';
import 'package:ecolindk/services/payment_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final String key = Platform.environment['NOTCH_API_KEY'] ?? '';
  final String? skip = key.isEmpty ? 'NOTCH_API_KEY not set' : null;

  Future<PaymentResult> pay(String phone, MobileMoneyOperator op) =>
      NotchPaySandboxGateway(publicKey: key, pollInterval: const Duration(seconds: 2)).collect(
        amountFcfa: 500,
        phone: phone,
        operator: op,
        reference: 'ecl_it_${DateTime.now().microsecondsSinceEpoch}',
        description: 'EcoLindk sandbox test',
      );

  test('MTN success number completes', () async {
    expect((await pay('+237670000000', MobileMoneyOperator.mtn)).status, PaymentStatus.success);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('Orange success number completes', () async {
    expect((await pay('+237690000000', MobileMoneyOperator.orange)).status, PaymentStatus.success);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('failure number fails', () async {
    expect((await pay('+237670000002', MobileMoneyOperator.mtn)).status, PaymentStatus.failed);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('canceled number is canceled', () async {
    expect((await pay('+237670000004', MobileMoneyOperator.mtn)).status, PaymentStatus.canceled);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
}
