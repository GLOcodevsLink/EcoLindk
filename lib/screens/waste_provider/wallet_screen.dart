import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/rewards_config.dart';
import '../../core/theme.dart';
import '../../models/wallet_models.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';
import 'redeem_screen.dart';
import 'transactions_screen.dart';

/// Portefeuille : solde FCFA (carte principale), total de points gagnés à
/// vie, grille de conversion (crédit/mobile data/retrait/envoi — les mêmes
/// options que l'encart de l'accueil). L'historique (points ET factures)
/// n'est plus affiché ici : voir TransactionsScreen, ouvert via le lien
/// "Mes transactions" de la carte principale.
class WalletScreen extends StatefulWidget {
  final bool embedded;
  const WalletScreen({super.key, this.embedded = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _authService = AuthService();
  final _walletService = WalletService();

  void _openRedeem(RedemptionMethod method) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RedeemScreen(method: method)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUser?.uid ?? '';
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Stack(
            children: [
              const DecorativeLeaves(subtle: true),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Row(
                      children: [
                        if (!widget.embedded)
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                        Text(fr ? "Portefeuille" : "Wallet",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.heading)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<int>(
                      stream: uid.isEmpty ? const Stream.empty() : _walletService.watchBalance(uid),
                      builder: (context, snap) {
                        final points = snap.data ?? 0;
                        final fcfa = RewardsConfig.fcfaForPoints(points);
                        return _heroCard(context, fcfa, fr);
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<int>(
                      stream: uid.isEmpty ? const Stream.empty() : _walletService.watchLifetimeEarned(uid),
                      builder: (context, snap) => _lifetimeCard(snap.data ?? 0, fr),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        fr
                            ? "Taux actuel : ${RewardsConfig.conversionThresholdPoints} points = ${RewardsConfig.conversionValueFcfa} FCFA"
                            : "Current rate: ${RewardsConfig.conversionThresholdPoints} points = ${RewardsConfig.conversionValueFcfa} FCFA",
                        style: TextStyle(fontSize: 11, color: AppColors.textGray, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(fr ? "Convertir mes points" : "Convert my points"),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.7,
                      children: [
                        // Palette limitée à vert/jaune (demande explicite,
                        // les mêmes couleurs que le donut "Cette semaine"
                        // et la grille "Convertir mes points" de l'accueil)
                        // — plus de bleu/violet/orange ici.
                        _redeemTile(Icons.phone_android_rounded, fr ? "Crédit téléphonique" : "Airtime",
                            RedemptionMethod.airtime, AppColors.amber),
                        _redeemTile(Icons.wifi_rounded, fr ? "Forfait internet" : "Mobile data",
                            RedemptionMethod.mobileData, AppColors.greenDeep),
                        _redeemTile(Icons.account_balance_outlined, fr ? "Retirer" : "Withdraw",
                            RedemptionMethod.withdrawal, AppColors.greenDeep),
                        _redeemTile(Icons.card_giftcard_outlined, fr ? "Envoyer à un proche" : "Send to relative",
                            RedemptionMethod.sendToRelative, AppColors.amber),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
      },
    );
  }

  /// Carte "hero" du Portefeuille — dégradé vert de marque (même
  /// [AppColors.buttonGradient] que la carte "Mes points", pour rester dans
  /// le thème de l'app). Ne montre plus les points (demande explicite :
  /// "remove the points on it") — seulement le solde en FCFA ("Main
  /// Balance"), précédé d'un badge "échange" (deux flèches qui se
  /// rejoignent, une blanche une verte) et suivi d'un lien vers le détail
  /// (voir [TransactionsScreen], qui regroupe maintenant historique des
  /// points ET des factures — sortis d'ici pour que cette carte reste un
  /// simple résumé).
  Widget _heroCard(BuildContext context, double fcfa, bool fr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.greenMid.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _exchangeBadge(),
              const SizedBox(width: 12),
              Text(fr ? "Solde principal" : "Main Balance",
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 10),
          Text("${fcfa.toStringAsFixed(0)} FCFA",
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransactionsScreen())),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fr ? "Mes transactions" : "My transactions",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white70)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Badge "échange" : deux flèches pleines et épaisses (pas des icônes
  /// Material, trop fines) qui se rejoignent tête contre tête au centre, en
  /// DIAGONALE — pas horizontales, pas verticales (demande explicite : "they
  /// should joint towards each other but in a diagonal way but one is up
  /// the other one is down but their head are joining side to side"). On
  /// part de la même paire "gauche pointe vers le centre / droite pointe
  /// vers le centre" qu'une horizontale classique (leurs têtes déjà côte à
  /// côte, au même niveau) puis on fait pivoter l'ENSEMBLE en bloc : la
  /// moitié gauche (blanche) se retrouve à pointer en diagonale vers le
  /// haut, la moitié droite (verte) en diagonale vers le bas — exactement
  /// comme les pictogrammes de change des apps bancaires. Posées
  /// directement sur le dégradé de la carte, sans cercle ni bordure (demande
  /// explicite : "without the border necessarily"). Une blanche, l'autre
  /// verte (demande explicite).
  Widget _exchangeBadge() {
    const arrowSize = Size(16, 22);
    return SizedBox(
      width: 40,
      height: 36,
      child: Center(
        child: Transform.rotate(
          angle: -0.55,
          child: SizedBox(
            width: arrowSize.width * 2,
            height: arrowSize.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  child: CustomPaint(
                      size: arrowSize,
                      painter: const _ThickArrowPainter(color: Colors.white, horizontal: true)),
                ),
                Positioned(
                  right: 0,
                  child: Transform(
                    alignment: Alignment.center,
                    // Miroir horizontal : la même silhouette (pointe côté
                    // "w" de son propre repère) se retrouve donc pointe à
                    // gauche une fois retournée, vers le centre depuis la
                    // droite.
                    transform: Matrix4.rotationY(math.pi),
                    child: CustomPaint(
                        size: arrowSize,
                        painter: const _ThickArrowPainter(color: AppColors.greenBright, horizontal: true)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bandeau "Total gagné" — total de points gagnés depuis toujours (ne
  /// baisse jamais, contrairement au solde), même esprit que "Your all-time
  /// savings" sur le prototype de référence, en vert clair pour rester dans
  /// le thème.
  Widget _lifetimeCard(int lifetimeEarned, bool fr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.greenBright.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greenBright.withOpacity(0.28), width: 1.2),
      ),
      child: Row(
        children: [
          BoxLogo(Icons.military_tech_rounded, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fr ? "Total de points gagnés" : "Total points earned",
                    style: TextStyle(fontSize: 11, color: AppColors.textGray, fontWeight: FontWeight.w700)),
                Text("$lifetimeEarned pts",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _redeemTile(IconData icon, String label, RedemptionMethod method, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openRedeem(method),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Fond de carte adapté au thème (pas de blanc en dur, demande
          // explicite : visible aussi en mode sombre) — seul le logo porte
          // la couleur vert/jaune.
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.2),
        ),
        child: Row(
          children: [
            BoxLogo(icon, size: 40, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flèche pleine (tige épaisse + pointe triangulaire), dessinée à la main
/// plutôt qu'une icône Material — celles-ci restent fines même à grande
/// taille, alors que [WalletScreen._exchangeBadge] demande des flèches
/// nettement plus épaisses. Pointe vers le haut par défaut (tête en haut, à
/// y=0) ; avec [horizontal], la même silhouette est tracée couchée à plat,
/// pointe à droite (tête à x=w) — utilisé par le badge "échange", dont les
/// deux flèches sont désormais côte à côte plutôt qu'empilées.
class _ThickArrowPainter extends CustomPainter {
  final Color color;
  final bool horizontal;
  const _ThickArrowPainter({required this.color, this.horizontal = false});

  @override
  void paint(Canvas canvas, Size size) {
    final path = horizontal ? _horizontalPath(size) : _verticalPath(size);
    canvas.drawPath(path, Paint()..color = color);
  }

  Path _verticalPath(Size size) {
    final w = size.width, h = size.height;
    final headH = h * 0.55;
    final shaftHalfW = w * 0.18;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, headH)
      ..lineTo(w * 0.5 + shaftHalfW, headH)
      ..lineTo(w * 0.5 + shaftHalfW, h)
      ..lineTo(w * 0.5 - shaftHalfW, h)
      ..lineTo(w * 0.5 - shaftHalfW, headH)
      ..lineTo(0, headH)
      ..close();
  }

  Path _horizontalPath(Size size) {
    final w = size.width, h = size.height;
    final headW = w * 0.55;
    final shaftHalfH = h * 0.18;
    return Path()
      ..moveTo(w, h * 0.5)
      ..lineTo(w - headW, 0)
      ..lineTo(w - headW, h * 0.5 - shaftHalfH)
      ..lineTo(0, h * 0.5 - shaftHalfH)
      ..lineTo(0, h * 0.5 + shaftHalfH)
      ..lineTo(w - headW, h * 0.5 + shaftHalfH)
      ..lineTo(w - headW, h)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _ThickArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.horizontal != horizontal;
}
