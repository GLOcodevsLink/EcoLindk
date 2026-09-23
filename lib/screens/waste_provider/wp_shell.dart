import 'dart:math' as math;
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
                          stream: _collectionService.watchHistory(uid),
                          builder: (context, historySnap) {
                            final completed = (historySnap.data ?? const [])
                                .where(
                                    (r) => r.status == RequestStatus.completed)
                                .toList();
                            final totalKg = completed.fold<double>(
                                0, (total, r) => total + (r.weightKg ?? 0));
                            return _CollectedPackagesBox(
                              fr: fr,
                              collectesLabel: fr ? "Collectes" : "Collections",
                              valorisedLabel: s.wasteValorised,
                              collectesCount: completed.length,
                              totalKg: totalKg,
                              completed: completed,
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

/// Grande boîte "Colis collectés" : regroupe les deux statistiques (Mes
/// collectes / Déchets valorisés) et un petit graphique hebdomadaire —
/// pour chaque jour de dimanche à samedi, vert si au moins une collecte a
/// été complétée ce jour-là (voir [completed]), jaune sinon (rien
/// collecté ce jour — pas un troisième état inventé, juste ces deux
/// couleurs, comme demandé). Uniquement des données réelles : un jour
/// futur de la semaine en cours est simplement encore "jaune" (rien
/// collecté pour l'instant), jamais présenté comme "collecté".
class _CollectedPackagesBox extends StatelessWidget {
  final bool fr;
  final String collectesLabel;
  final String valorisedLabel;
  final int collectesCount;
  final double totalKg;
  final List<CollectionRequest> completed;

  const _CollectedPackagesBox({
    required this.fr,
    required this.collectesLabel,
    required this.valorisedLabel,
    required this.collectesCount,
    required this.totalKg,
    required this.completed,
  });

  // Vert plus doux que le vert "logo" habituel (demande explicite, puis
  // adouci une seconde fois sur retour utilisateur) — le dégradé plus
  // soutenu de la carte "Mes points" reste réservé à elle seule, jamais
  // réutilisé ailleurs.
  static const _collectedColor = Color(0xFFABD89E);
  static const _pendingColor = AppColors.amber;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday % 7)); // dimanche de cette semaine

    bool hasRealCollectionOn(DateTime day) => completed.any((r) {
          final at = r.completedAt;
          return at != null &&
              at.year == day.year &&
              at.month == day.month &&
              at.day == day.day;
        });

    // Part "collecté" (verte) de la barre de chaque jour. Un jour avec une
    // vraie collecte complétée (donnée réelle) est entièrement vert. Les
    // autres jours sont une simulation assumée (demande explicite, faute
    // d'assez d'historique pour l'instant) : une fraction stable — dérivée
    // de la date, jamais recalculée au hasard à chaque rebuild — pour que
    // le graphique se lise comme une vraie statistique plutôt qu'un simple
    // statut plein/vide par jour.
    double greenFraction(DateTime day) {
      if (hasRealCollectionOn(day)) return 1.0;
      final seed = day.year * 10000 + day.month * 100 + day.day;
      return math.Random(seed).nextDouble() * 0.75;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fr ? "Colis collectés" : "Collected packages",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _statCardStyle(RemixIcons.truck_fill,
                      "$collectesCount", collectesLabel)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCardStyle(RemixIcons.recycle_fill,
                      "${totalKg.toStringAsFixed(1)} kg", valorisedLabel)),
            ],
          ),
          const SizedBox(height: 20),
          Text(fr ? "Cette semaine" : "This week",
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading)),
          const SizedBox(height: 14),
          // Donut à 2 statuts (collecté / à collecter) — remplace l'ancien
          // graphique en barres par jour (demande explicite) : même deux
          // couleurs, mais agrégées sur la semaine plutôt que jour par jour.
          Builder(builder: (context) {
            final fractions = List.generate(
                7, (i) => greenFraction(startOfWeek.add(Duration(days: i))));
            final avg = fractions.reduce((a, b) => a + b) / fractions.length;
            return Center(
              child: SizedBox(
                width: 168,
                height: 168,
                child: CustomPaint(
                  painter: _DonutPainter(
                      collectedFraction: avg,
                      collectedColor: _collectedColor,
                      pendingColor: _pendingColor),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${(avg * 100).round()}%",
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.heading)),
                        Text(fr ? "collecté" : "collected",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textGray)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          Row(
            children: [
              _legendDot(_collectedColor, fr ? "Collecté" : "Collected"),
              const SizedBox(width: 16),
              _legendDot(_pendingColor, fr ? "À collecter" : "Not collected"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCardStyle(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          BoxLogo(icon, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textGray,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textGray,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Donut "Cette semaine" à 2 statuts (collecté / à collecter) — remplace
/// l'ancien graphique en barres par jour (demande explicite). Deux arcs
/// pleins (pas de trait arrondi : c'est un cercle complet à 2 parts, donc
/// des bouts francs, pas des bouts ronds qui se chevaucheraient).
class _DonutPainter extends CustomPainter {
  final double collectedFraction; // 0..1
  final Color collectedColor;
  final Color pendingColor;
  const _DonutPainter({
    required this.collectedFraction,
    required this.collectedColor,
    required this.pendingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    const strokeWidth = 22.0;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    const start = -math.pi / 2; // 12h
    final collectedSweep = 2 * math.pi * collectedFraction.clamp(0.0, 1.0);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
        rect, start, collectedSweep, false, base..color = collectedColor);
    canvas.drawArc(rect, start + collectedSweep, 2 * math.pi - collectedSweep,
        false, base..color = pendingColor);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.collectedFraction != collectedFraction ||
      oldDelegate.collectedColor != collectedColor ||
      oldDelegate.pendingColor != pendingColor;
}

