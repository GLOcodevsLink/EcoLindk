import 'dart:math';

import 'package:ecolindk/services/otp_simulation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late SimulatedOtpService otp;

  setUp(() {
    now = DateTime(2026, 9, 29, 10);
    otp = SimulatedOtpService(random: Random(1), now: () => now);
  });

  test('génère un code à 6 chiffres', () {
    expect(otp.send(), matches(RegExp(r'^\d{6}$')));
  });

  test('aucun code envoyé → noCode', () {
    expect(otp.verify('123456'), OtpCheck.noCode);
  });

  test('bon code → valid, puis inutilisable une seconde fois', () {
    final code = otp.send();
    expect(otp.verify(' $code '), OtpCheck.valid);
    expect(otp.verify(code), OtpCheck.noCode);
  });

  test('mauvais code → invalid, et un essai de moins', () {
    final code = otp.send();
    final wrong = code == '000000' ? '111111' : '000000';
    expect(otp.verify(wrong), OtpCheck.invalid);
    expect(otp.attemptsLeft, SimulatedOtpService.maxAttempts - 1);
  });

  test('code expiré après 5 minutes', () {
    final code = otp.send();
    now = now.add(SimulatedOtpService.validity + const Duration(seconds: 1));
    expect(otp.verify(code), OtpCheck.expired);
  });

  test('bloqué après 5 erreurs, même avec le bon code', () {
    final code = otp.send();
    final wrong = code == '000000' ? '111111' : '000000';
    for (var i = 0; i < SimulatedOtpService.maxAttempts - 1; i++) {
      expect(otp.verify(wrong), OtpCheck.invalid);
    }
    expect(otp.verify(wrong), OtpCheck.tooManyAttempts);
    expect(otp.verify(code), OtpCheck.tooManyAttempts);
  });

  test('renvoyer un code : délai de 30 s, puis nouveau code et essais remis à zéro', () {
    final first = otp.send();
    otp.verify(first == '000000' ? '111111' : '000000');
    expect(otp.resendWait, SimulatedOtpService.resendCooldown);

    now = now.add(const Duration(seconds: 12));
    expect(otp.resendWait, const Duration(seconds: 18));

    now = now.add(const Duration(seconds: 18));
    expect(otp.resendWait, Duration.zero);
    final second = otp.send();
    expect(otp.attemptsLeft, SimulatedOtpService.maxAttempts);
    if (second != first) expect(otp.verify(first), OtpCheck.invalid);
    expect(otp.verify(second), OtpCheck.valid);
  });
}
