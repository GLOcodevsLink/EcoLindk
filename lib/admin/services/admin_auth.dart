import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

/// Connexion au tableau de bord : même email/mot de passe Firebase que
/// l'app mobile (via AuthService.signIn). La déconnexion n'utilise PAS
/// AuthService.signOut, qui appelle aussi GoogleSignIn — non configuré sur
/// le web, il lèverait une erreur.
class AdminAuth {
  AdminAuth({FirebaseAuth? auth, AuthService? authService})
      : _auth = auth ?? FirebaseAuth.instance,
        _injectedAuthService = authService;

  final FirebaseAuth _auth;
  final AuthService? _injectedAuthService;

  // Créé au premier usage seulement : AuthService ouvre aussi Firestore.
  late final AuthService _authService = _injectedAuthService ?? AuthService(auth: _auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signIn(String email, String password) => _authService.signIn(email: email, password: password);

  Future<void> signOut() => _auth.signOut();
}
