import 'package:ecolindk/services/otp_simulation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late SimulatedOtpService otp;

  setUp(() {
    now = DateTime(2026, 9, 29, 10);
    otp = SimulatedOtpService(now: () => now);
  });

  test('the verification code is 123456', () {
    expect(otp.send(), '123456');
  });

  test('no code sent → noCode', () {
    expect(otp.verify('123456'), OtpCheck.noCode);
  });

  test('right code → valid, then unusable a second time', () {
    final code = otp.send();
    expect(otp.verify(' $code '), OtpCheck.valid);
    expect(otp.verify(code), OtpCheck.noCode);
  });

  test('wrong code → invalid, one attempt fewer', () {
    final code = otp.send();
    final wrong = code == '000000' ? '111111' : '000000';
    expect(otp.verify(wrong), OtpCheck.invalid);
    expect(otp.attemptsLeft, SimulatedOtpService.maxAttempts - 1);
  });

  test('code expires after 5 minutes', () {
    final code = otp.send();
    now = now.add(SimulatedOtpService.validity + const Duration(seconds: 1));
    expect(otp.verify(code), OtpCheck.expired);
  });

  test('locked after 5 failures, even with the right code', () {
    final code = otp.send();
    final wrong = code == '000000' ? '111111' : '000000';
    for (var i = 0; i < SimulatedOtpService.maxAttempts - 1; i++) {
      expect(otp.verify(wrong), OtpCheck.invalid);
    }
    expect(otp.verify(wrong), OtpCheck.tooManyAttempts);
    expect(otp.verify(code), OtpCheck.tooManyAttempts);
  });

  test('resending a code: 30 s delay, then a new code and attempts reset', () {
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
