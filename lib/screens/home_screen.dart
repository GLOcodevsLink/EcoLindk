import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/contact_service.dart';
import 'collector/collector_shell.dart';
import 'collector_setup_screen.dart';
import 'email_verification_screen.dart';
import 'role_selection_screen.dart';
import 'waste_provider/wp_shell.dart';

/// Point d'entrée post-connexion : lit le rôle de l'utilisateur (Ménage/
/// Fournisseur de déchets ou Collecteur) depuis sa fiche Firestore puis
/// bascule vers le dashboard dédié à ce rôle — [WasteProviderShell] ou
/// [CollectorShell], chacun avec sa propre barre de navigation basse à
/// onglets (IndexedStack, l'utilisateur navigue librement dans les deux
/// sens sans jamais empiler de pages redondantes).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  late final Future<DocumentSnapshot<Map<String, dynamic>>?> _userDocFuture;

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    _userDocFuture = uid == null ? Future.value(null) : _load(uid);
  }

  /// Relit d'abord l'état du compte auprès de Firebase : le lien a pu être
  /// cliqué depuis la dernière ouverture de l'app.
  Future<DocumentSnapshot<Map<String, dynamic>>> _load(String uid) async {
    try {
      await _authService.reloadEmailVerified();
    } catch (_) {}
    final DocumentSnapshot<Map<String, dynamic>> doc = await _authService.fetchUserDocument(uid);
    // Shares this user's phone with their chat contacts (Call button, see
    // ContactService) — also backfills accounts created before it existed.
    // Never blocks opening the app.
    ContactService()
        .publishOwnPhone(uid, doc.data()?['phone'] as String?)
        .catchError((Object e) => debugPrint('publishOwnPhone failed: $e'));
    return doc;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: _userDocFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            body: const Center(
                child:
                    CircularProgressIndicator(color: AppColors.greenMid)),
          );
        }

        final data = snapshot.data?.data();

        // Compte créé avec la vérification d'email (champ posé à
        // l'inscription) dont le lien n'a pas encore été cliqué : pas
        // d'accès à la plateforme. Les comptes plus anciens n'ont pas ce
        // champ et entrent normalement. Jamais pour un Collecteur (demande
        // explicite), y compris ceux inscrits quand le champ leur était
        // encore posé.
        final isCollector = data?['role'] == UserRole.collector.name ||
            data?['intendedRole'] == UserRole.collector.name;
        if (!isCollector &&
            data?['emailVerificationRequired'] == true &&
            _authService.currentUser?.emailVerified != true) {
          return EmailVerificationScreen(
            onVerified: (ctx) => Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          );
        }

        // Cas rare : le compte existe (email/mot de passe créé) mais
        // l'inscription a été interrompue avant le choix du rôle (ex.
        // l'app a été fermée entre les deux). On termine ce choix avant
        // d'afficher un dashboard.
        if (data != null && data['role'] == null) {
          final uid = _authService.currentUser!.uid;
          final firstName = (data['firstName'] as String?) ?? '';
          // Le rôle choisi à l'inscription est connu (`intendedRole`) : on
          // reprend là où elle s'est arrêtée. L'écran de choix du rôle ne
          // reste que pour les très anciens comptes, créés sans ce champ.
          final intended = data['intendedRole'] as String?;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => intended == UserRole.collector.name
                    ? CollectorSetupScreen(uid: uid, firstName: firstName)
                    : RoleSelectionScreen(uid: uid, firstName: firstName),
              ),
            );
          });
          return Scaffold(
            backgroundColor: AppColors.surface,
            body: const Center(
                child:
                    CircularProgressIndicator(color: AppColors.greenMid)),
          );
        }

        final role = (data?['role'] as String?) == UserRole.collector.name
            ? UserRole.collector
            : UserRole.household;

        return role == UserRole.collector
            ? const CollectorShell()
            : const WasteProviderShell();
      },
    );
  }
}
