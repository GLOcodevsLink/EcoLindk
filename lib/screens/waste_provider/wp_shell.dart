import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/user_avatar.dart';
import 'package:remixicon/remixicon.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../models/household_stats.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/messaging_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/modern_bottom_nav.dart';
import '../../widgets/points_card.dart';
import '../../widgets/wp_common.dart';
import '../settings/settings_screen.dart';
import 'ai_assistant_screen.dart';
import 'messages_screen.dart';
import 'my_collections_screen.dart';
import 'my_posts_screen.dart';
import 'notifications_center_screen.dart';
import 'post_waste_screen.dart';
import 'scan_screen.dart';
import 'wallet_screen.dart';

/// Point d'entrée du dashboard Fournisseur de déchets.
///
/// Barre de navigation basse "flottante" à 5 emplacements : Accueil /
/// Portefeuille / [bouton Scan central, plus grand, légèrement surélevé] /
/// Messages / Réglages — seuls Accueil, Portefeuille, Messages et Réglages
/// sont des onglets (IndexedStack, gardent leur état) ; le bouton Scan
/// central pousse [ScanScreen] par-dessus au lieu de changer d'onglet.
///
/// "Messages" ([MessagesScreen], onglet) et "Notifications" (cloche du
/// dashboard, qui pousse [NotificationsCenterScreen] par-dessus) sont
/// délibérément DEUX écrans différents — jamais le même contenu recyclé
/// sous deux noms.
///
/// "Poster un déchet" est un bouton flottant élargi (icône + texte), visible
/// uniquement sur l'onglet Accueil, au-dessus de la barre de navigation.
class WasteProviderShell extends StatefulWidget {
  const WasteProviderShell({super.key});

  @override
  State<WasteProviderShell> createState() => _WasteProviderShellState();
}

class _WasteProviderShellState extends State<WasteProviderShell> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  void _openScan() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ScanScreen()));
  }

  void _openPostWaste() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PostWasteScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        final s = AppStrings.of(lang);
        final tabs = [
          _WpDashboardTab(onOpenTab: _goToTab),
          const WalletScreen(embedded: true),
          const MessagesScreen(),
          const SettingsScreen(),
        ];
        return Scaffold(
          backgroundColor: AppColors.surface,
          // L'Assistant IA redevient un bandeau dans la page (voir
          // _WpDashboardTab) — la maquette de référence fournie par
          // l'utilisateur le montre ainsi, pas comme un bouton flottant.
          body: IndexedStack(index: _index, children: tabs),
          floatingActionButton: _index == 0 ? _postWasteFab(fr) : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          // Barre "flottante" façon Material 3 (voir doc de la classe et de
          // [ModernBottomNav]) : détachée des bords, indicateur en pilule
          // derrière l'onglet actif — remplace l'ancienne barre carrée
          // collée aux bords, jugée "trop classique".
          bottomNavigationBar: ModernBottomNav(
            currentIndex: _index,
            onTap: _goToTab,
            centerAction: _scanButton(fr),
            items: [
              ModernNavItem(
                  icon: RemixIcons.home_line,
                  activeIcon: RemixIcons.home_fill,
                  label: s.navHome),
              ModernNavItem(
                  icon: RemixIcons.wallet_line,
                  activeIcon: RemixIcons.wallet_fill,
                  label: s.navWallet),
              // Badge = messages non lus (voir MessagingService), pas des
              // notifications (voir cloche du dashboard pour celles-ci —
              // deux compteurs bien distincts).
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

  /// Bouton central "Scanner", agrandi et légèrement surélevé pour se
  /// détacher visuellement de la barre (voir doc de la classe) — un anneau
  /// de la couleur de la barre crée l'illusion qu'il "flotte" au-dessus.
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

  /// Bouton "Ajouter" — petit bouton compact (demande explicite : juste
  /// "Ajouter", plus le libellé long "Ajouter au recyclage" d'avant).
  Widget _postWasteFab(bool fr) {
    return GestureDetector(
      onTap: _openPostWaste,
      child: Container(
        // Largeur minimale commune : "Add" ne donne plus un bouton plus
        // petit que "Ajouter" (demande explicite : même rendu dans les deux
        // langues).
        constraints: const BoxConstraints(minWidth: 108),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: AppColors.greenMid.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(RemixIcons.add_fill, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(fr ? "Ajouter" : "Add",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Contenu de l'onglet Accueil, reproduit d'après la maquette de référence
/// fournie par l'utilisateur : carte "Mes points" en dégradé (trophée +
/// feuilles), bandeau Assistant IA (dans la page, pas flottant), actions
/// rapides (Mes collectes / Mes postes) et impact (nombre de collectes / kg
/// recyclés). Plus de section "Convertir mes points" (demande explicite :
/// retirée de l'accueil). Pas de section "Demande en cours" ici — voir
/// MyCollectionsScreen (onglet "En cours") pour le suivi détaillé.
class _WpDashboardTab extends StatefulWidget {
  final void Function(int tabIndex) onOpenTab;
  const _WpDashboardTab({required this.onOpenTab});

  @override
  State<_WpDashboardTab> createState() => _WpDashboardTabState();
}

class _WpDashboardTabState extends State<_WpDashboardTab> {
  final _authService = AuthService();
  final _collectionService = CollectionService();
  late final Future<DocumentSnapshot<Map<String, dynamic>>?> _userDocFuture;

  /// Tous les posts du Fournisseur, quel que soit leur statut — source des
  /// statistiques "Mon impact" (voir [HouseholdStats]). Créé une seule fois
  /// pour ne pas relancer la requête Firestore à chaque rafraîchissement.
  late final Stream<List<CollectionRequest>> _allRequests =
      _collectionService.watchAllRequests(_authService.currentUser?.uid ?? '');

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    _userDocFuture =
        uid == null ? Future.value(null) : _authService.fetchUserDocument(uid);
  }

  void _openAiAssistant() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AiAssistantScreen()));
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
                    // Marge basse : le bouton "Ajouter" et la barre de
                    // navigation flottent par-dessus (voir
                    // WasteProviderShell), pas dans le flux du scroll — sans
                    // cette réserve, le dernier contenu (la boîte "Colis
                    // collectés") se retrouverait caché dessous.
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
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
                                Text(s.homeSubtitle,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textGray,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const NotificationsCenterScreen())),
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
                            child: UserAvatar(
                              photoUrl: data?['photoUrl'] as String?,
                              fullName: (data?['fullName'] as String?) ?? '',
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ---- Carte "Mes points" (dégradé + trophée) ----
                      PointsCard(
                        uid: uid,
                        pointsLabel: s.myPoints,
                        buttonLabel:
                            fr ? "Voir le portefeuille" : "View wallet",
                        onButtonTap: () => widget.onOpenTab(1),
                      ),
                      const SizedBox(height: 22),

                      // Assistant IA : plus de bandeau ici — un petit bouton
                      // flottant dédié (voir WasteProviderShell) donne accès
                      // au chat, pour ne plus prendre de place dans la page
                      // ni risquer de chevaucher quoi que ce soit.

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
                          _actionCard(
                              RemixIcons.truck_fill,
                              fr ? "Mes collectes" : "My collections",
                              () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const MyCollectionsScreen()))),
                          _actionCard(
                              RemixIcons.apps_fill,
                              fr ? "Mes postes" : "My posts",
                              () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const MyPostsScreen()))),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ---- Assistant IA (bandeau dans la page, comme sur
                      // la maquette de référence) ----
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _openAiAssistant,
                        child: Container(
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
                                    color: Colors.white,
                                    shape: BoxShape.circle),
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
                          stream: _allRequests,
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return InlineErrorBanner(
                                  message: fr
                                      ? "Impossible de charger vos statistiques."
                                      : "Couldn't load your statistics.");
                            }
                            return _StatsBox(
                              fr: fr,
                              valorisedLabel: s.wasteValorised,
                              stats: HouseholdStats.from(snap.data ?? const []),
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

  Widget _actionCard(IconData icon, String label, VoidCallback onTap) {
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
            BoxLogo(icon),
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
}

/// "Mon impact" : vraies statistiques du Fournisseur, calculées sur TOUS
/// ses posts (voir [HouseholdStats]) — chiffres clés, répartition de ses
/// posts par statut, kg collectés sur les 7 derniers jours et par
/// catégorie. Aucune valeur inventée : sans collecte, les barres restent à
/// zéro et un message l'indique.
class _StatsBox extends StatelessWidget {
  final bool fr;
  final String valorisedLabel;
  final HouseholdStats stats;

  const _StatsBox({required this.fr, required this.valorisedLabel, required this.stats});

  static const _collectedColor = Color(0xFF3FA66B);
  static const _inProgressColor = AppColors.amber;
  static const _cancelledColor = Color(0xFFBFC6C2);

  static String _kg(double v) =>
      "${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} kg";

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Chiffres clés
          Row(
            children: [
              Expanded(child: _stat(RemixIcons.truck_fill, "${s.completedCount}", fr ? "Collectes" : "Collections")),
              const SizedBox(width: 10),
              Expanded(child: _stat(RemixIcons.recycle_fill, _kg(s.totalKg), valorisedLabel)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _stat(RemixIcons.coins_fill, "${s.totalPoints} P", fr ? "Points gagnés" : "Points earned")),
              const SizedBox(width: 10),
              Expanded(child: _stat(RemixIcons.time_fill, "${s.inProgressCount}", fr ? "Posts en cours" : "Posts in progress")),
            ],
          ),
          const SizedBox(height: 22),

          // ---- Mes posts par statut
          _title(fr ? "Mes posts" : "My posts"),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(
                  painter: _DonutPainter(segments: [
                    (s.completedCount.toDouble(), _collectedColor),
                    (s.inProgressCount.toDouble(), _inProgressColor),
                    (s.cancelledCount.toDouble(), _cancelledColor),
                  ]),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.totalPosts == 0 ? "—" : "${(s.completionRate * 100).round()}%",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.heading)),
                        Text(fr ? "collectés" : "collected",
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textGray)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow(_collectedColor, fr ? "Collectés" : "Collected", s.completedCount),
                    _legendRow(_inProgressColor, fr ? "En cours" : "In progress", s.inProgressCount),
                    _legendRow(_cancelledColor, fr ? "Annulés" : "Cancelled", s.cancelledCount),
                    const Divider(height: 14),
                    _legendRow(null, fr ? "Total" : "Total", s.totalPosts, bold: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---- 7 derniers jours
          Row(
            children: [
              Expanded(child: _title(fr ? "7 derniers jours" : "Last 7 days")),
              Text(_kg(s.last7Days.fold(0.0, (t, d) => t + d.kg)),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
            ],
          ),
          const SizedBox(height: 12),
          _weekBars(),
          if (s.maxDailyKg == 0) ...[
            const SizedBox(height: 8),
            Text(
                fr ? "Aucune collecte terminée ces 7 derniers jours." : "No completed pickup in the last 7 days.",
                style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
          ],

          // ---- Par catégorie
          if (s.kgByCategory.isNotEmpty) ...[
            const SizedBox(height: 24),
            _title(fr ? "Par catégorie" : "By category"),
            const SizedBox(height: 12),
            ...s.kgByCategory.map((e) => _categoryBar(e.key, e.value, s.totalKg)),
          ],
        ],
      ),
    );
  }

  Widget _title(String text) =>
      Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.heading));

  Widget _stat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          BoxLogo(icon, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.heading)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, color: AppColors.textGray, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color? color, String label, int count, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (color != null)
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
          else
            const SizedBox(width: 10),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: bold ? AppColors.heading : AppColors.textGray, fontWeight: FontWeight.w700)),
          ),
          Text("$count",
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.heading)),
        ],
      ),
    );
  }

  /// Une barre par jour, hauteur proportionnelle aux kg collectés ce
  /// jour-là ; aujourd'hui en dernier et mis en évidence.
  Widget _weekBars() {
    final days = stats.last7Days;
    final maxKg = stats.maxDailyKg;
    final initials = fr ? const ['L', 'M', 'M', 'J', 'V', 'S', 'D'] : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const barArea = 96.0;
    return SizedBox(
      height: barArea + 38,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (days[i].kg > 0)
                    Text(_kg(days[i].kg).replaceAll(' kg', ''),
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: 18,
                    height: maxKg == 0 ? 4 : math.max(4, barArea * days[i].kg / maxKg),
                    decoration: BoxDecoration(
                      gradient: days[i].kg > 0 ? AppColors.buttonGradient : null,
                      color: days[i].kg > 0 ? null : AppColors.line,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(initials[days[i].day.weekday - 1],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == days.length - 1 ? FontWeight.w900 : FontWeight.w600,
                          color: i == days.length - 1 ? AppColors.greenDeep : AppColors.textGray)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryBar(WasteCategory c, double kg, double total) {
    final share = total == 0 ? 0.0 : kg / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(9)),
            child: Icon(c.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(c.label(fr),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.heading)),
                    ),
                    Text("${_kg(kg)} · ${(share * 100).round()}%",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.color)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6,
                    color: c.color,
                    backgroundColor: c.color.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Anneau à plusieurs parts (valeur, couleur). Sans aucune valeur, un
/// anneau gris neutre.
class _DonutPainter extends CustomPainter {
  final List<(double, Color)> segments;
  const _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    const strokeWidth = 18.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final total = segments.fold<double>(0, (t, s) => t + s.$1);
    if (total == 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = AppColors.line);
      return;
    }
    var start = -math.pi / 2; // 12h
    for (final (value, color) in segments) {
      if (value <= 0) continue;
      final sweep = 2 * math.pi * value / total;
      canvas.drawArc(rect, start, sweep, false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    if (oldDelegate.segments.length != segments.length) return true;
    for (var i = 0; i < segments.length; i++) {
      if (oldDelegate.segments[i] != segments[i]) return true;
    }
    return false;
  }
}

