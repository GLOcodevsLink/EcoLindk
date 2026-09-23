import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import 'collector/collector_shell.dart';
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
    _userDocFuture =
        uid == null ? Future.value(null) : _authService.fetchUserDocument(uid);
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

        // Cas rare : le compte existe (email/mot de passe créé) mais
        // l'inscription a été interrompue avant le choix du rôle (ex.
        // l'app a été fermée entre les deux). On termine ce choix avant
        // d'afficher un dashboard.
        if (data != null && data['role'] == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => RoleSelectionScreen(
                  uid: _authService.currentUser!.uid,
                  firstName: (data['firstName'] as String?) ?? '',
                ),
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
