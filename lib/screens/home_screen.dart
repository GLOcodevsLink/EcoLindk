import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';
import '../widgets/decorative_leaves.dart';
import '../widgets/points_card.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import 'profile_screen.dart';
import 'role_selection_screen.dart';
import 'settings/settings_screen.dart';
import 'waste_provider/messages_screen.dart';
import 'waste_provider/wp_shell.dart';

/// Home Page (dashboard) — reproduit la maquette : carte "Mes points" en
/// dégradé, grille d'actions rapides, bandeau Assistant IA, statistiques
/// d'impact, barre de navigation basse avec bouton Scanner central.
///
/// Le contenu (sous-titre, actions rapides) s'adapte au rôle de
/// l'utilisateur (Ménage / Collecteur), lu depuis sa fiche Firestore.
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: appLanguage,
          builder: (context, lang, _) {
            final s = AppStrings.of(lang);
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: _userDocFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Scaffold(
                    backgroundColor: AppColors.surface,
                    body: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.greenMid)),
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
                        child: CircularProgressIndicator(
                            color: AppColors.greenMid)),
                  );
                }

                final firstName = (data?['firstName'] as String?)?.trim();
                final userName = (firstName != null && firstName.isNotEmpty)
                    ? firstName
                    : (data?['fullName'] as String?)?.split(' ').first ?? '';
                final role =
                    (data?['role'] as String?) == UserRole.collector.name
                        ? UserRole.collector
                        : UserRole.household;
                final isPendingCollector = role == UserRole.collector &&
                    data?['verificationStatus'] == 'pending';

                // Le Fournisseur de déchets a son propre dashboard (module
                // waste_provider/) — voir sa doc. Le Collecteur garde pour
                // l'instant le dashboard générique ci-dessous, en attendant
                // la prochaine étape (son propre module dédié).
                if (role == UserRole.household) {
                  return const WasteProviderShell();
                }

                return _dashboard(s, userName, role, isPendingCollector);
              },
            );
          },
        );
      },
    );
  }

  Widget _dashboard(
      AppStrings s, String userName, UserRole role, bool isPendingCollector) {
    final greetingText = userName.isEmpty
        ? "${s.greeting} ! 👋"
        : "${s.greeting}, $userName ! 👋";
    final subtitle =
        role == UserRole.collector ? s.homeSubtitleCollector : s.homeSubtitle;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const DecorativeLeaves(subtle: true),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu, color: AppColors.heading),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(greetingText,
                                    style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.heading)),
                                Text(subtitle,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textGray)),
                              ],
                            ),
                          ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.notifications_none,
                                  color: AppColors.heading),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle),
                                  child: const Text("9",
                                      style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MessagesScreen())),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    color: AppColors.heading),
                                if (_authService.currentUser != null)
                                  StreamBuilder<int>(
                                    stream: MessagingService()
                                        .watchTotalUnread(_authService.currentUser!.uid),
                                    builder: (context, snap) {
                                      final count = snap.data ?? 0;
                                      if (count == 0) return const SizedBox.shrink();
                                      return Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                              color: Colors.redAccent, shape: BoxShape.circle),
                                          child: Text(count > 9 ? '9+' : '$count',
                                              style: const TextStyle(
                                                  fontSize: 8,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.line,
                            child: Icon(Icons.person,
                                size: 18, color: AppColors.textGray),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (isPendingCollector) ...[
                        _pendingBanner(s),
                        const SizedBox(height: 18),
                      ],

                      // Carte points — même carte "premium" (dégradé +
                      // trophée illustré) que le dashboard Fournisseur de
                      // déchets, voir [PointsCard] : bouton et destination
                      // ("Voir mon profil") différents, rendu identique.
                      PointsCard(
                        uid: _authService.currentUser?.uid ?? '',
                        pointsLabel: s.myPoints,
                        buttonLabel: s.viewProfile,
                        onButtonTap: () => _openProfile(context),
                      ),
                      const SizedBox(height: 20),

                      Text(s.quickActions,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.heading)),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.6,
                        children: role == UserRole.collector
                            ? [
                                _actionCard(Icons.local_shipping_outlined,
                                    s.collectorTasksLabel),
                                _actionCard(
                                    Icons.history, s.collectorHistoryLabel),
                                _actionCard(Icons.storefront_outlined,
                                    s.recyclablesMarket),
                                _actionCard(Icons.apartment_outlined,
                                    s.recyclingCenters),
                              ]
                            : [
                                _actionCard(
                                    Icons.qr_code_scanner, s.declareWaste),
                                _actionCard(
                                    Icons.local_shipping_outlined, s.myPickups),
                                _actionCard(Icons.storefront_outlined,
                                    s.recyclablesMarket),
                                _actionCard(Icons.apartment_outlined,
                                    s.recyclingCenters),
                              ],
                      ),
                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6FB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.smart_toy_outlined,
                                  color: Color(0xFF2094C4), size: 19),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.aiAssistant,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5)),
                                  Text(s.aiAssistantDesc,
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textGray)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 13, color: Color(0xFF2094C4)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(s.myImpact,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.heading)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: _statCard(
                                  Icons.groups_outlined, "12", s.pickups)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _statCard(
                                  Icons.recycling, "8.5 kg", s.wasteValorised)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _statCard(
                                  Icons.park_outlined, "45", s.treesSaved)),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                _bottomNav(s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingBanner(AppStrings s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_outlined,
              size: 17, color: Color(0xFF8A6D00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.accountPendingBanner,
                style: TextStyle(
                    fontSize: 11.5, color: Color(0xFF8A6D00), height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.greenBright.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.greenDeep),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading)),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.greenMid),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: AppColors.textGray)),
        ],
      ),
    );
  }

  /// Ouvre directement la modification du profil (utilisé par le raccourci
  /// "Voir mon profil" de la carte points).
  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Widget _bottomNav(AppStrings s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line, width: 1.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, s.navHome, active: true),
          _navItem(Icons.list_alt_outlined, s.navPickups),
          _scannerButton(),
          _navItem(Icons.chat_bubble_outline, s.navMessages),
          _navItem(Icons.settings_outlined, s.navSettings,
              onTap: () => _openSettings(context)),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label,
      {bool active = false, VoidCallback? onTap}) {
    final color = active ? AppColors.greenMid : AppColors.textGray;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _scannerButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: AppColors.greenMid.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
    );
  }
}
