import 'package:ecolindk/core/l10n/app_language.dart';
import 'package:ecolindk/core/l10n/strings.dart';
import 'package:ecolindk/core/phone_country.dart';
import 'package:ecolindk/services/otp_simulation_service.dart';
import 'package:ecolindk/services/waste_photo_service.dart';
import 'package:ecolindk/widgets/user_avatar.dart';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Tests unitaires du module Authentification : chaque test vérifie une
/// seule classe ou fonction, sans base de données ni réseau.
void main() {
  group('OTP code', () {
    late DateTime now;
    late SimulatedOtpService otp;

    setUp(() {
      now = DateTime(2026, 9, 29, 10);
      otp = SimulatedOtpService(now: () => now);
    });

    String wrongCodeFor(String code) => code == '000000' ? '111111' : '000000';

    test('the verification code is 123456', () {
      expect(otp.send(), '123456');
      expect(SimulatedOtpService.verificationCode, '123456');
    });

    test('accepts the right code', () {
      final code = otp.send();
      expect(otp.verify(code), OtpCheck.valid);
    });

    test('a code can only be used once', () {
      final code = otp.send();
      otp.verify(code);
      expect(otp.verify(code), OtpCheck.noCode);
    });

    test('rejects a wrong code and counts the attempt', () {
      final code = otp.send();
      expect(otp.verify(wrongCodeFor(code)), OtpCheck.invalid);
      expect(otp.attemptsLeft, SimulatedOtpService.maxAttempts - 1);
    });

    test('rejects a code entered after 5 minutes', () {
      final code = otp.send();
      now = now.add(const Duration(minutes: 5, seconds: 1));
      expect(otp.verify(code), OtpCheck.expired);
    });

    test('locks after 5 wrong attempts, even with the right code', () {
      final code = otp.send();
      for (var i = 0; i < SimulatedOtpService.maxAttempts; i++) {
        otp.verify(wrongCodeFor(code));
      }
      expect(otp.verify(code), OtpCheck.tooManyAttempts);
    });

    test('a new code can be requested after 30 seconds', () {
      otp.send();
      expect(otp.resendWait, const Duration(seconds: 30));
      now = now.add(const Duration(seconds: 30));
      expect(otp.resendWait, Duration.zero);
    });

    test('verifying before any code was sent is refused', () {
      expect(otp.verify('123456'), OtpCheck.noCode);
    });
  });

  group('Authentication error messages', () {
    final en = AppStrings.of(AppLanguage.en);
    final fr = AppStrings.of(AppLanguage.fr);

    test('an email already used gives a clear message', () {
      expect(en.authError('email-already-in-use'), contains('already exists'));
    });

    test('a wrong password or email gives the same message', () {
      expect(en.authError('wrong-password'), 'Incorrect email or password.');
      expect(en.authError('invalid-credential'), 'Incorrect email or password.');
    });

    test('a weak password explains the password rules', () {
      expect(en.authError('weak-password'), contains('8 characters'));
    });

    test('a network problem is reported as such', () {
      expect(en.authError('network-request-failed'), contains('Network error'));
    });

    test('an unknown error gives a generic message', () {
      expect(en.authError('something-new'), 'Something went wrong. Please try again.');
    });

    test('messages are also available in French', () {
      expect(fr.authError('wrong-password'), 'Email ou mot de passe incorrect.');
    });
  });

  group('Profile photo', () {
    Uint8List photo(int w, int h) => Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h)));

    test('a profile photo is cropped to a 512 x 512 square', () {
      final out = img.decodeJpg(compressAvatar(photo(3000, 2000)))!;
      expect(out.width, 512);
      expect(out.height, 512);
    });

    test('a small profile photo is cropped to a square, not enlarged', () {
      final out = img.decodeJpg(compressAvatar(photo(300, 200)))!;
      expect(out.width, 200);
      expect(out.height, 200);
    });

    test('a file that is not an image is rejected', () {
      expect(() => compressAvatar(Uint8List.fromList([1, 2, 3])), throwsA(isA<WastePhotoException>()));
    });

    test('initials are shown when there is no photo', () {
      expect(UserAvatar.initialsOf('Awa Ngono'), 'AN');
      expect(UserAvatar.initialsOf('Paul'), 'P');
      expect(UserAvatar.initialsOf('  '), '');
    });
  });

  group('Country from phone number', () {
    test('+237 is Cameroon', () {
      expect(countryFromPhone('+237650123456')!.countryCode, 'CM');
    });

    test('dialing codes of 2 and 3 digits are recognized', () {
      expect(countryFromPhone('+33612345678')!.countryCode, 'FR');
      expect(countryFromPhone('+2250102030405')!.countryCode, 'CI');
    });

    test('a number without dialing code gives no country', () {
      expect(countryFromPhone('650123456'), isNull);
      expect(countryFromPhone(''), isNull);
    });
  });
}
