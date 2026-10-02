import 'dart:typed_data';

import 'package:ecolindk/models/user_role.dart';
import 'package:ecolindk/services/auth_service.dart';
import 'package:ecolindk/services/otp_simulation_service.dart';
import 'package:ecolindk/services/waste_photo_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as img;
import 'package:mock_exceptions/mock_exceptions.dart';

/// Google Sign-In n'est pas utilisé ici ; seule la déconnexion est appelée.
class TestGoogleSignIn extends Fake implements GoogleSignIn {
  @override
  Future<GoogleSignInAccount?> signOut() async => null;
}

const email = 'awa@example.com';
const password = 'secret123';
const phone = '+237650123456';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  AuthService authWith(MockFirebaseAuth auth) =>
      AuthService(auth: auth, firestore: db, googleSignIn: TestGoogleSignIn());

  Future<Map<String, dynamic>?> profileOf(String uid) async =>
      (await db.collection('users').doc(uid).get()).data();

  Future<UserCredential> register(AuthService auth, {UserRole role = UserRole.household}) =>
      auth.registerAccount(
        email: email,
        password: password,
        firstName: 'Awa',
        lastName: 'Ngono',
        address: '',
        phoneNumber: phone,
        role: role,
        phoneVerified: true,
      );

  group('Phone verification (OTP)', () {
    test('entering 123456 verifies the phone number', () {
      final otp = SimulatedOtpService()..send();
      expect(otp.verify('123456'), OtpCheck.valid);
    });

    test('a wrong code is rejected and the attempt is counted', () {
      final otp = SimulatedOtpService()..send();
      expect(otp.verify('000000'), OtpCheck.invalid);
      expect(otp.attemptsLeft, SimulatedOtpService.maxAttempts - 1);
    });
  });

  group('Sign-up', () {
    test('waste supplier: profile saved with its role, verified phone and email verification required', () async {
      final auth = authWith(MockFirebaseAuth(verifyEmailAutomatically: false));
      final cred = await register(auth);

      final profile = (await profileOf(cred.user!.uid))!;
      expect(profile['email'], email);
      expect(profile['fullName'], 'Awa Ngono');
      expect(profile['role'], 'household');
      expect(profile['verificationStatus'], 'verified');
      expect(profile['phone'], phone);
      expect(profile['phoneVerified'], isTrue);
      expect(profile['emailVerificationRequired'], isTrue);
      expect(profile['address'], '');
    });

    test('collector: role saved as intended and finalized after the setup step', () async {
      final auth = authWith(MockFirebaseAuth(verifyEmailAutomatically: false));
      final cred = await register(auth, role: UserRole.collector);
      final uid = cred.user!.uid;

      expect((await profileOf(uid))!['role'], isNull);
      expect((await profileOf(uid))!['intendedRole'], 'collector');
      // Pas de vérification d'email pour le Collecteur.
      expect((await profileOf(uid))!['emailVerificationRequired'], isFalse);

      await auth.completeCollectorRegistration(uid, workStatus: WorkStatus.independent);
      expect((await profileOf(uid))!['role'], 'collector');
      expect((await profileOf(uid))!['verificationStatus'], 'verified');
    });

    test('the optional company name is saved on the profile', () async {
      final auth = authWith(MockFirebaseAuth(verifyEmailAutomatically: false));
      final cred = await auth.registerAccount(
        email: email, password: password, firstName: 'Awa', lastName: 'Ngono', address: '',
        phoneNumber: phone, role: UserRole.household, companyName: '  EcoCollect SARL ', phoneVerified: true);
      expect((await profileOf(cred.user!.uid))!['companyName'], 'EcoCollect SARL');
    });

    test('without a company name, nothing is saved for it', () async {
      final auth = authWith(MockFirebaseAuth(verifyEmailAutomatically: false));
      final cred = await register(auth);
      expect((await profileOf(cred.user!.uid))!['companyName'], isNull);
    });

    test('the phone number is linked to the email for phone login', () async {
      final auth = authWith(MockFirebaseAuth(verifyEmailAutomatically: false));
      await register(auth);
      expect(await auth.findEmailForPhone(phone), email);
    });

    test('an interrupted sign-up is resumed with the same email and password', () async {
      final first = authWith(MockFirebaseAuth(verifyEmailAutomatically: false));
      final uid = (await register(first, role: UserRole.collector)).user!.uid;

      // Second essai : Firebase répond "email déjà utilisé" pour ce compte
      // jamais terminé (rôle pas encore choisi).
      final mock = MockFirebaseAuth(mockUser: MockUser(uid: uid, email: email, isEmailVerified: false));
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(mock)
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      final cred = await register(authWith(mock), role: UserRole.collector);

      expect(cred.user!.uid, uid);
      expect((await profileOf(uid))!['intendedRole'], 'collector');
    });

    test('an existing complete account is not taken over: email-already-in-use', () async {
      await db.collection('users').doc('done').set({'role': 'household', 'email': email});
      final mock = MockFirebaseAuth(mockUser: MockUser(uid: 'done', email: email));
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(mock)
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      await expectLater(
        register(authWith(mock)),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'email-already-in-use')),
      );
      expect(mock.currentUser, isNull); // déconnecté, rien n'a été modifié
      expect((await profileOf('done'))!['role'], 'household');
    });

    test('restarting the sign-up deletes the profile and the phone entry', () async {
      final mock = MockFirebaseAuth(verifyEmailAutomatically: false);
      final auth = authWith(mock);
      final uid = (await register(auth)).user!.uid;

      // Rôle pas encore finalisé pour un collecteur : la fiche peut être annulée.
      await db.collection('users').doc(uid).update({'role': null});
      await auth.abandonRegistration();

      expect(await profileOf(uid), isNull);
      expect(await auth.findEmailForPhone(phone), isNull);
      expect(mock.currentUser, isNull);
    });
  });

  group('Profile photo', () {
    test('a profile photo is stored and linked to the profile', () async {
      final auth = authWith(MockFirebaseAuth(verifyEmailAutomatically: false));
      final uid = (await register(auth)).user!.uid;

      final photos = WastePhotoService(firestore: db);
      final original = Uint8List.fromList(img.encodeJpg(img.Image(width: 1200, height: 900)));
      final ref = await photos.uploadAvatar(uid, original);
      await auth.updateProfilePhoto(uid, ref);

      expect((await profileOf(uid))!['photoUrl'], ref);
      final stored = img.decodeJpg((await photos.load(ref))!)!;
      expect(stored.width, 512);
      expect(stored.height, 512);
    });

    test('the profile photo can be removed', () async {
      final auth = authWith(MockFirebaseAuth(verifyEmailAutomatically: false));
      final uid = (await register(auth)).user!.uid;
      await auth.updateProfilePhoto(uid, 'firestore://wastePhotos/abc');
      await auth.updateProfilePhoto(uid, null);
      expect((await profileOf(uid))!['photoUrl'], isNull);
    });
  });

  group('Email verification', () {
    test('access stays blocked while Firebase has not verified the email', () async {
      final auth = authWith(MockFirebaseAuth(
          signedIn: true, mockUser: MockUser(uid: 'u1', email: email, isEmailVerified: false)));
      expect(await auth.reloadEmailVerified(), isFalse);
    });

    test('access is granted once the link has been clicked (email verified)', () async {
      final auth = authWith(MockFirebaseAuth(
          signedIn: true, mockUser: MockUser(uid: 'u1', email: email, isEmailVerified: true)));
      expect(await auth.reloadEmailVerified(), isTrue);
    });
  });

  group('Login', () {
    test('signs in with email and password', () async {
      final mock = MockFirebaseAuth(mockUser: MockUser(uid: 'u1', email: email));
      final cred = await authWith(mock).signIn(email: ' $email ', password: password);
      expect(cred.user!.uid, 'u1');
      expect(mock.currentUser!.email, email);
    });

    test('wrong password is rejected', () async {
      final mock = MockFirebaseAuth(mockUser: MockUser(uid: 'u1', email: email));
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mock)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      await expectLater(
        () => authWith(mock).signIn(email: email, password: 'bad'),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'wrong-password')),
      );
      expect(mock.currentUser, isNull);
    });

    test('phone login: an unknown number has no account', () async {
      final auth = authWith(MockFirebaseAuth());
      expect(await auth.findEmailForPhone('+237699999999'), isNull);
    });

    test('signs out', () async {
      final mock = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1', email: email));
      await authWith(mock).signOut();
      expect(mock.currentUser, isNull);
    });
  });
}
