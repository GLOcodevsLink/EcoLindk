import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/messaging_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/modern_bottom_nav.dart';
import '../settings/settings_screen.dart';
import '../waste_provider/messages_screen.dart';
import '../waste_provider/notifications_center_screen.dart';
import '../waste_provider/scan_screen.dart';
import 'collector_commission_screen.dart';
import 'collector_history_screen.dart';
import 'collector_tasks_screen.dart';

/// Point d'entrée du dashboard Collecteur — pendant de [WasteProviderShell]
/// pour ce rôle (voir sa doc). Même barre de navigation basse "flottante" à
/// 5 emplacements : Accueil / Collectes / [bouton Scan central] / Messages /
/// Réglages — seuls Accueil, Collectes, Messages et Réglages sont des
/// onglets (IndexedStack, gardent leur état) ; le bouton Scan central pousse
/// [ScanScreen] par-dessus au lieu de changer d'onglet.
///
/// Avant ce shell, "Collectes"/"Messages"/"Réglages" étaient ouverts par des
/// `Navigator.push` distincts depuis un dashboard sans onglets réel (barre
/// dont l'indicateur restait figé sur "Accueil") : on ne pouvait pas revenir
/// à un onglet déjà ouvert sans empiler les pages precedentes. L'IndexedStack
/// corrige ça — chaque onglet garde son état et on navigue librement entre
/// eux dans les deux sens.
class CollectorShell extends StatefulWidget {
  const CollectorShell({super.key});

  @override
  State<CollectorShell> createState() => _CollectorShellState();
}

class _CollectorShellState extends State<CollectorShell> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  void _openScan() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ScanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        final s = AppStrings.of(lang);
        final tabs = [
          _CollectorDashboardTab(onOpenTab: _goToTab),
          const CollectorTasksScreen(embedded: true),
          const MessagesScreen(),
          const SettingsScreen(),
        ];
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: IndexedStack(index: _index, children: tabs),
          bottomNavigationBar: ModernBottomNav(
            currentIndex: _index,
            onTap: _goToTab,
            centerAction: _scanButton(fr),
            items: [
              ModernNavItem(
                  icon: RemixIcons.home_line,
                  activeIcon: RemixIcons.home_fill,
                  label: s.navHome),
              // Icône camion plutôt qu'une simple liste — plus expressive de
              // ce que l'onglet représente (les collectes à récupérer).
              ModernNavItem(
                  icon: RemixIcons.truck_line,
                  activeIcon: RemixIcons.truck_fill,
                  label: s.navPickups),
              ModernNavItem(
                  icon: RemixIcons.message_line,
                  activeIcon: RemixIcons.message_fill,
                  label: s.navMessages,
                  badge: AuthService().currentUser == null
                      ? null
                      : MessagingService()
                          .watchTotalUnread(AuthService().currentUser!.uid)),
              ModernNavItem(
                  icon: RemixIcons.settings_line,
                  activeIcon: RemixIcons.settings_fill,
                  label: s.navSettings),
            ],
          ),
        );
      },
    );
  }

  /// Bouton central "Scanner" : le Collecteur y scanne le QR code affiché
  /// par le Fournisseur au moment de la collecte pour ouvrir directement le
  /// suivi de cette demande (voir ScanScreen).
  Widget _scanButton(bool fr) {
    return GestureDetector(
      onTap: _openScan,
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration:
                  BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.greenMid.withOpacity(0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: const Icon(RemixIcons.qr_code_fill,
                    color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(height: 2),
            Text(fr ? "Scanner" : "Scan",
                style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.greenDark,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Contenu de l'onglet Accueil du Collecteur — repris du dashboard générique
/// qui vivait auparavant dans home_screen.dart, adapté pour vivre comme
/// onglet (plus de barre de navigation propre : elle vient de
/// [CollectorShell]).
class _CollectorDashboardTab extends StatefulWidget {
  final void Function(int tabIndex) onOpenTab;
  const _CollectorDashboardTab({required this.onOpenTab});

  @override
  State<_CollectorDashboardTab> createState() =>
      _CollectorDashboardTabState();
}

class _CollectorDashboardTabState extends State<_CollectorDashboardTab> {
  final _authService = AuthService();
  late final Future<DocumentSnapshot<Map<String, dynamic>>?> _userDocFuture;

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    _userDocFuture =
        uid == null ? Future.value(null) : _authService.fetchUserDocument(uid);
  }

  void _openTasksTab() => widget.onOpenTab(1);

  void _openCollectorHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CollectorHistoryScreen()),
    );
  }

  void _openCommission() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CollectorCommissionScreen()),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUser?.uid ?? '';
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        final s = AppStrings.of(lang);
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          future: _userDocFuture,
          builder: (context, snap) {
            final data = snap.data?.data();
            final firstName = (data?['firstName'] as String?)?.trim() ?? '';
            final greeting = firstName.isEmpty
                ? "${s.greeting} ! 👋"
                : "${s.greeting}, $firstName ! 👋";

            return Stack(
              children: [
                const DecorativeLeaves(subtle: true),
                SafeArea(
                  child: ListView(
                    // Marge basse : la barre de navigation flotte par-dessus
                    // (voir CollectorShell), pas dans le flux du scroll.
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      Row(
                        children: [
                          Icon(RemixIcons.menu_line, color: AppColors.heading),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(greeting,
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.heading)),
                                Text(s.homeSubtitleCollector,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textGray,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _openNotifications,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(RemixIcons.notification_line,
                                    color: AppColors.heading, size: 25),
                                if (uid.isNotEmpty)
                                  StreamBuilder<int>(
                                    stream: NotificationService()
                                        .watchUnreadCount(uid),
                                    builder: (context, notifSnap) {
                                      final count = notifSnap.data ?? 0;
                                      if (count == 0)
                                        return const SizedBox.shrink();
                                      return Positioned(
                                        right: -3,
                                        top: -3,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle),
                                          child: Text(
                                              count > 9 ? '9+' : '$count',
                                              style: const TextStyle(
                                                  fontSize: 8.5,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () => widget.onOpenTab(3),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.line,
                              child: Icon(RemixIcons.user_fill,
                                  size: 20, color: AppColors.textGray),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ---- Actions rapides ----
                      Text(s.quickActions,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.heading)),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.3,
                        children: [
                          _actionCard(RemixIcons.truck_fill,
                              s.collectorTasksLabel, _openTasksTab),
                          _actionCard(RemixIcons.history_fill,
                              s.collectorHistoryLabel, _openCollectorHistory),
                          _actionCard(RemixIcons.store_fill,
                              s.recyclablesMarket, null),
                          _actionCard(RemixIcons.building_fill,
                              s.recyclingCenters, null),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ---- Assistant IA ----
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6FB),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(RemixIcons.robot_fill,
                                  color: Color(0xFF2094C4), size: 34),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.aiAssistant,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                  Text(s.aiAssistantDesc,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textGray,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ---- Commission + Premium ----
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _openCommission,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF1DC),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                child: const Icon(
                                    Icons.workspace_premium_outlined,
                                    color: Color(0xFFB8860B),
                                    size: 30),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Commission & Premium",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16)),
                                    Text(
                                        fr
                                            ? "Vos transactions du mois et l'abonnement Premium"
                                            : "This month's transactions and the Premium plan",
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textGray,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                    gradient: AppColors.buttonGradient,
                                    shape: BoxShape.circle),
                                child: const Icon(RemixIcons.arrow_right_fill,
                                    color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ---- Mon impact ----
                      Text(s.myImpact,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.heading)),
                      const SizedBox(height: 12),
                      if (uid.isEmpty)
                        const SizedBox.shrink()
                      else
                        StreamBuilder<List<CollectionRequest>>(
                          stream: CollectionService().watchCollectorHistory(uid),
                          builder: (context, historySnap) {
                            final completed = (historySnap.data ?? const [])
                                .where(
                                    (r) => r.status == RequestStatus.completed)
                                .toList();
                            final totalKg = completed.fold<double>(
                                0, (total, r) => total + (r.weightKg ?? 0));
                            return Row(
                              children: [
                                Expanded(
                                    child: _statCard(RemixIcons.group_fill,
                                        "${completed.length}", s.pickups)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(
                                        RemixIcons.recycle_fill,
                                        "${totalKg.toStringAsFixed(1)} kg",
                                        s.wasteValorised)),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _actionCard(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line, width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
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
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading)),
            ),
          ],
        ),
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
}
