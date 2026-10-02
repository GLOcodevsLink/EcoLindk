import 'package:ecolindk/core/l10n/app_language.dart';
import 'package:ecolindk/screens/otp_verification_screen.dart';
import 'package:ecolindk/screens/register_screen.dart';
import 'package:ecolindk/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests d'interface de l'authentification : l'écran est réellement
/// affiché, puis le test tape du texte et touche des boutons comme un
/// utilisateur. L'app est passée en anglais pour ces tests.

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> fillIdentity(WidgetTester tester, {String password = 'secret123', String? confirm}) async {
  await tester.enterText(field('FIRST NAME'), 'Awa');
  await tester.enterText(field('LAST NAME'), 'Ngono');
  await tester.enterText(field('EMAIL'), 'awa@example.com');
  await tester.enterText(field('PASSWORD'), password);
  await tester.enterText(field('CONFIRM PASSWORD'), confirm ?? password);
}

Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => appLanguage.value = AppLanguage.en);
  tearDown(() => appLanguage.value = AppLanguage.fr);

  group('Sign-up form', () {
    Future<void> openForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on the waste supplier form, in 2 steps', (tester) async {
      await openForm(tester);
      expect(find.text('Waste Supplier'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(field('FIRST NAME'), findsOneWidget);
      expect(field('EMAIL'), findsOneWidget);
    });

    testWidgets('choosing Collector keeps the same 2-step form', (tester) async {
      await openForm(tester);
      await tester.tap(find.text('Collector'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(field('FIRST NAME'), findsOneWidget);
    });

    testWidgets('empty fields are rejected', (tester) async {
      await openForm(tester);
      await tapNext(tester);
      expect(find.text('Required field'), findsWidgets);
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('a password shorter than 8 characters is rejected', (tester) async {
      await openForm(tester);
      await fillIdentity(tester, password: 'abc1');
      await tapNext(tester);
      expect(find.text('Minimum 8 characters'), findsOneWidget);
    });

    testWidgets('a password without a number is rejected', (tester) async {
      await openForm(tester);
      await fillIdentity(tester, password: 'abcdefgh');
      await tapNext(tester);
      expect(find.text('Password must contain at least one number'), findsOneWidget);
    });

    testWidgets('passwords that do not match are rejected', (tester) async {
      await openForm(tester);
      await fillIdentity(tester, password: 'secret123', confirm: 'secret456');
      await tapNext(tester);
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('waste supplier goes straight to the phone step (no address asked)', (tester) async {
      await openForm(tester);
      await fillIdentity(tester);
      await tapNext(tester);
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.text('Your phone number'), findsOneWidget);
      expect(find.text('Where do you live?'), findsNothing);
      expect(find.text('Sign up'), findsWidgets);
    });

    testWidgets('the phone step has an optional company name field, before the terms', (tester) async {
      await openForm(tester);
      await fillIdentity(tester);
      await tapNext(tester);

      final company = field('COMPANY NAME (optional)');
      expect(company, findsOneWidget);
      // Placé après le numéro et avant l'acceptation des conditions.
      final companyY = tester.getTopLeft(company).dy;
      expect(companyY, greaterThan(tester.getTopLeft(find.text('Your phone number')).dy));
      expect(companyY, lessThan(tester.getTopLeft(find.byType(Checkbox)).dy));

      await tester.enterText(company, 'EcoCollect SARL');
      expect(find.text('EcoCollect SARL'), findsOneWidget);
    });

    testWidgets('collector also goes straight to the phone step (no address asked)', (tester) async {
      await openForm(tester);
      await tester.tap(find.text('Collector'));
      await tester.pumpAndSettle();
      await fillIdentity(tester);
      await tapNext(tester);
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.text('Your phone number'), findsOneWidget);
      expect(find.text('Where do you live?'), findsNothing);
    });
  });

  group('Profile avatar', () {
    testWidgets('without a photo, the avatar shows the initials', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UserAvatar(photoUrl: null, fullName: 'Awa Ngono'))));
      expect(find.text('AN'), findsOneWidget);
    });

    testWidgets('without a photo or a name, the avatar shows a person icon', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UserAvatar(photoUrl: null))));
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('with a photo, the photo is shown instead of the initials', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: UserAvatar(photoUrl: 'https://example.com/me.jpg', fullName: 'Awa Ngono'))));
      expect(find.text('AN'), findsNothing);
      expect(find.byType(ClipOval), findsOneWidget);
    });
  });

  group('Phone verification screen (OTP)', () {
    testWidgets('tells the user a code was sent, without showing the code', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OtpVerificationScreen(phoneNumber: '+237690000001')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Verify your number'), findsOneWidget);
      expect(find.textContaining('A verification code was sent by SMS to +237690000001'), findsOneWidget);
      expect(find.textContaining('123456'), findsNothing);

      await tester.pumpWidget(const SizedBox()); // arrête les minuteries de l'écran
    });

    testWidgets('a wrong code shows an error message', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OtpVerificationScreen(phoneNumber: '+237650123456')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump();

      expect(find.textContaining('Wrong code'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('entering 123456 validates the phone and closes the screen', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const OtpVerificationScreen(phoneNumber: '+237650123456')),
              );
            },
            child: const Text('Create my account'),
          ),
        ),
      ));
      await tester.tap(find.text('Create my account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Verify your number'), findsNothing);
    });
  });
}
