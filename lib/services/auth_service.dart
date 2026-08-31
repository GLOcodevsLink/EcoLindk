import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_role.dart';

/// Statut de vérification d'un compte, stocké dans Firestore.
/// - Ménage : vérifié automatiquement dès le choix du rôle.
/// - Collecteur : "pending" jusqu'à validation par un administrateur.
enum VerificationStatus { verified, pending }

extension VerificationStatusValue on VerificationStatus {
  String get value => switch (this) {
        VerificationStatus.verified => 'verified',
        VerificationStatus.pending => 'pending',
      };
}

/// Encapsule Firebase Auth (email/mot de passe + vérification téléphone par
/// SMS) et la fiche utilisateur Firestore associée (collection `users`, un
/// document par uid).
///
/// Flow d'inscription :
/// 1. [verifyPhoneNumber] envoie le code SMS.
/// 2. [registerWithPhone] crée le compte email/mot de passe, y lie le
///    numéro vérifié, et crée le document Firestore (sans rôle).
/// 3. [completeHouseholdRegistration] ou [completeCollectorRegistration]
///    fixe le rôle et finalise le compte.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Lance l'envoi du code SMS vers [phoneNumber] (format E.164, ex.
  /// "+237650123456"). Sur Android, si Play Services parvient à vérifier le
  /// numéro automatiquement (sans saisie de code), [onAutoVerified] est
  /// appelé directement avec un credential déjà valide.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException e) onFailed,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    int? forceResendingToken,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Crée le compte email/mot de passe puis la fiche Firestore associée
  /// (rôle non défini pour l'instant, choisi juste après).
  ///
  /// [phoneCredential] : le credential obtenu après vérification SMS
  /// (`FirebaseAuth.verifyPhoneNumber`, voir [verifyPhoneNumber] ci-dessous),
  /// construit par RegisterScreen une fois le code entré par l'utilisateur.
  /// Il est lié au compte tout juste créé ; `phoneVerificationSimulated`
  /// reste à `true` seulement si aucun credential n'a pu être fourni (ex.
  /// numéro non vérifiable), pour distinguer ces cas plus tard.
  ///
  /// Si la liaison du téléphone échoue (code invalide/expiré), le compte
  /// Auth tout juste créé est supprimé pour permettre à l'utilisateur de
  /// réessayer avec le même email.
  Future<UserCredential> registerAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String address,
    required String phoneNumber,
    PhoneAuthCredential? phoneCredential,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (phoneCredential != null) {
      try {
        await credential.user!.linkWithCredential(phoneCredential);
      } catch (_) {
        await credential.user?.delete();
        rethrow;
      }
    }

    await _createUserDocument(credential.user!.uid, {
      'email': email.trim(),
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'fullName': '${firstName.trim()} ${lastName.trim()}',
      'address': address.trim(),
      'phone': phoneNumber,
      'phoneVerified': true,
      'phoneVerificationSimulated': phoneCredential == null,
      'role': null,
      'verificationStatus': null,
    });

    return credential;
  }

  /// Finalise un compte Ménage : vérifié immédiatement.
  Future<void> completeHouseholdRegistration(String uid) {
    return _users.doc(uid).update({
      'role': UserRole.household.name,
      'verificationStatus': VerificationStatus.verified.value,
    });
  }

  /// Finalise un compte Collecteur : statut "pending" en attente de
  /// validation admin.
  Future<void> completeCollectorRegistration(
    String uid, {
    required String collectionZone,
    required WorkStatus workStatus,
    String? companyName,
  }) {
    return _users.doc(uid).update({
      'role': UserRole.collector.name,
      'verificationStatus': VerificationStatus.pending.value,
      'collectionZone': collectionZone.trim(),
      'workStatus': workStatus.name,
      'companyName': (companyName == null || companyName.trim().isEmpty)
          ? null
          : companyName.trim(),
    });
  }

  Future<void> _createUserDocument(String uid, Map<String, dynamic> fields) {
    return _users.doc(uid).set({
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      ...fields,
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchUserDocument(
    String uid,
  ) {
    return _users.doc(uid).get();
  }

  Future<void> signOut() => _auth.signOut();
}
