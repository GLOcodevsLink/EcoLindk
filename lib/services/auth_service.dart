import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

/// Encapsule Firebase Auth (email/mot de passe) et la fiche utilisateur
/// Firestore associée (collection `users`, un document par uid).
///
/// Flow d'inscription :
/// 1. [registerAccount] crée le compte email/mot de passe et le document
///    Firestore (sans rôle), avec le numéro de téléphone renseigné tel quel
///    (aucune vérification par SMS n'est requise).
/// 2. [completeHouseholdRegistration] ou [completeCollectorRegistration]
///    fixe le rôle et finalise le compte.
///
/// Flow de connexion (voir LoginScreen) : email+mot de passe, ou
/// téléphone+mot de passe via [findEmailForPhone]. Pas de second facteur
/// (2FA) — ni code SMS ni code email — car les deux nécessitent le plan
/// payant Firebase (Blaze) : SMS via Firebase Phone Auth, email via une
/// Cloud Function. Retirés intentionnellement ; voir git history si besoin
/// de les réactiver plus tard.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  // `phone_lookup/{phoneNumber}` : petit index public en lecture (voir
  // firestore.rules) qui associe un numéro de téléphone à l'email du
  // compte correspondant, uniquement pour permettre à l'onglet "Téléphone"
  // de LoginScreen de retrouver l'email et appeler [signIn] normalement
  // (Firebase Auth n'a pas de "mot de passe + téléphone"). Renseigné à
  // l'inscription dans [registerAccount].
  CollectionReference<Map<String, dynamic>> get _phoneLookup =>
      _firestore.collection('phone_lookup');

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Ouvre le sélecteur de compte Google natif, puis échange le credential
  /// obtenu contre une session Firebase Auth. Crée la fiche Firestore si
  /// c'est la première connexion (voir [_ensureUserDocument]) — le rôle
  /// reste `null`, ce qui déclenche automatiquement RoleSelectionScreen
  /// (voir HomeScreen) exactement comme pour un compte email/mot de passe
  /// tout juste inscrit.
  ///
  /// Lève une [FirebaseAuthException] au code `sign-in-canceled` si
  /// l'utilisateur ferme le sélecteur sans choisir de compte.
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(code: 'sign-in-canceled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await _ensureUserDocument(userCredential.user!);
    return userCredential;
  }

  /// Connexion "Sign in with Apple" via le flux OAuth générique de Firebase
  /// Auth (`OAuthProvider('apple.com')`) — pas besoin du plugin natif
  /// `sign_in_with_apple` : Firebase gère lui-même la page web Apple puis
  /// l'échange de session, exactement comme pour Google mais sans SDK tiers.
  /// Nécessite qu'Apple soit configuré comme fournisseur dans la console
  /// Firebase (Services ID + clé, ce qui suppose un compte Apple Developer
  /// payant — contrairement à Google, gratuit).
  Future<UserCredential> signInWithApple() async {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    final userCredential = await _auth.signInWithProvider(provider);
    await _ensureUserDocument(userCredential.user!);
    return userCredential;
  }

  Future<void> _ensureUserDocument(User user) async {
    final doc = await _users.doc(user.uid).get();
    if (doc.exists) return;

    final displayName = (user.displayName ?? '').trim();
    final parts =
        displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    await _createUserDocument(user.uid, {
      'email': user.email ?? '',
      'firstName': firstName,
      'lastName': lastName,
      'fullName': displayName,
      'address': '',
      'phone': user.phoneNumber ?? '',
      'role': null,
      'verificationStatus': null,
    });
  }

  /// `true` si le compte connecté peut se réauthentifier par mot de passe
  /// (donc doit passer par ce chemin pour [changePassword] /
  /// [deleteAccount]) ; `false` s'il n'a que Google comme fournisseur, auquel
  /// cas la réauthentification repasse par [signInWithGoogle].
  bool get hasPasswordProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID) ??
      true;

  /// Envoie l'email "mot de passe oublié" standard de Firebase Auth — lien
  /// vers la page de réinitialisation hébergée par Firebase elle-même
  /// (`<projectId>.firebaseapp.com/__/auth/action`), aucune configuration
  /// supplémentaire requise.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Retrouve l'email associé à [phone] via [_phoneLookup], pour permettre
  /// la connexion depuis l'onglet "Téléphone". Retourne `null` si aucun
  /// compte n'a ce numéro.
  Future<String?> findEmailForPhone(String phone) async {
    final doc = await _phoneLookup.doc(phone).get();
    return doc.data()?['email'] as String?;
  }

  /// Crée le compte email/mot de passe puis la fiche Firestore associée
  /// (rôle non défini pour l'instant, choisi juste après). Le numéro de
  /// téléphone est enregistré tel qu'il a été saisi, sans vérification par
  /// SMS.
  Future<UserCredential> registerAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String address,
    required String phoneNumber,
    String? referredBy,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await _createUserDocument(credential.user!.uid, {
      'email': email.trim(),
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'fullName': '${firstName.trim()} ${lastName.trim()}',
      'address': address.trim(),
      'phone': phoneNumber,
      'role': null,
      'verificationStatus': null,
      // Uid du parrain (voir ReferralService) — `null` si aucun code de
      // parrainage n'a été saisi. Lu par ReferralService.creditIfQualifying
      // quand ce nouveau compte termine sa première collecte qualifiante.
      'referredBy': referredBy,
    });

    if (phoneNumber.trim().isNotEmpty) {
      await _phoneLookup.doc(phoneNumber.trim()).set({'email': email.trim()});
    }

    return credential;
  }

  /// Finalise un compte Ménage : vérifié immédiatement.
  Future<void> completeHouseholdRegistration(String uid) {
    return _users.doc(uid).update({
      'role': UserRole.household.name,
      'verificationStatus': VerificationStatus.verified.value,
    });
  }

  /// Finalise un compte Collecteur : vérifié immédiatement, comme un compte
  /// Ménage (demande explicite : "il ne devrait pas avoir ça [la validation
  /// admin], il crée juste son compte et puis c'est tout — lorsqu'il crée il
  /// peut tout faire ce qui le concerne").
  Future<void> completeCollectorRegistration(
    String uid, {
    required String collectionZone,
    required WorkStatus workStatus,
    String? companyName,
  }) {
    return _users.doc(uid).update({
      'role': UserRole.collector.name,
      'verificationStatus': VerificationStatus.verified.value,
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

  /// Met à jour des champs libres de la fiche profil (nom, adresse, zone de
  /// collecte…). `role` et `verificationStatus` sont exclus côté
  /// firestore.rules — un appel qui tenterait de les changer serait rejeté.
  Future<void> updateProfileFields(String uid, Map<String, dynamic> fields) {
    return _users.doc(uid).update(fields);
  }

  /// Change le mot de passe du compte connecté. Firebase exige une connexion
  /// "récente" pour cette opération : on réauthentifie donc d'abord avec
  /// [currentPassword] (lève `wrong-password`/`invalid-credential` s'il est
  /// incorrect) avant d'appliquer [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Supprime définitivement le compte : réauthentifie d'abord — par mot de
  /// passe ([password], compte email/mot de passe) ou en rouvrant le
  /// sélecteur Google ([hasPasswordProvider] == false) — puis nettoie
  /// l'index `phone_lookup` (si [phone] est renseigné), la fiche Firestore,
  /// et enfin le compte Firebase Auth lui-même. Ordre important : la fiche
  /// Firestore est supprimée avant le compte Auth, tant que les règles (qui
  /// vérifient `request.auth.uid == userId`) peuvent encore l'autoriser.
  Future<void> deleteAccount({
    String? password,
    String? phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }

    if (hasPasswordProvider) {
      if (password == null || password.isEmpty || user.email == null) {
        throw FirebaseAuthException(code: 'no-current-user');
      }
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } else if (user.providerData
        .any((p) => p.providerId == 'apple.com')) {
      await user.reauthenticateWithProvider(OAuthProvider('apple.com'));
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(code: 'sign-in-canceled');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }

    if (phone != null && phone.trim().isNotEmpty) {
      await _phoneLookup.doc(phone.trim()).delete();
    }
    await _users.doc(user.uid).delete();
    await user.delete();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
