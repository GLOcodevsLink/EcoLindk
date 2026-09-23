import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import '../core/theme.dart';
import '../services/wallet_service.dart';

/// Carte "Mes points" — dégradé + trophée illustré (badge doré + feuilles),
/// reproduisant la maquette de référence fournie par l'utilisateur (capture
/// d'écran) : label discret, "1 234 pts" en gros avec séparateur de
/// milliers, pastille blanche "Voir ..." avec flèche, trophée sur cercle vert
/// entouré d'un bouquet de feuilles asymétrique.
///
/// Widget PARTAGÉ (lib/widgets/) car deux dashboards l'affichent avec un
/// texte de bouton et une destination différents — le fournisseur de déchets
/// (wp_shell.dart, bouton "Voir le portefeuille") et le collecteur
/// (home_screen.dart, bouton "Voir mon profil") — mais doivent rester
/// visuellement identiques : dupliquer ce widget aurait fait diverger le
/// rendu au fil des retouches futures.
class PointsCard extends StatelessWidget {
  final String uid;
  final String pointsLabel;
  final String buttonLabel;
  final VoidCallback onButtonTap;

  const PointsCard({
    super.key,
    required this.uid,
    required this.pointsLabel,
    required this.buttonLabel,
    required this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Même vert que le bouton "Ajouter au recyclage" (demande
        // explicite : "the mes points box color should be of the same as
        // ajouter au recyclage").
        gradient: AppColors.pointsCardGradient,
        borderRadius: BorderRadius.circular(22),
        // Halo coloré sous la carte — jamais posée à plat sur la page,
        // pour un rendu plus "premium" (demande : "beautify the box more").
        boxShadow: [
          BoxShadow(
              color: AppColors.greenMid.withOpacity(0.38),
              blurRadius: 22,
              offset: const Offset(0, 10)),
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Reflet diagonal en haut à gauche — un aplat de dégradé tout
            // seul reste plat ; ce voile clair donne un peu de brillant/
            // relief à la carte, comme un vrai badge plutôt qu'un rectangle.
            Positioned(
              top: -30,
              left: -30,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: 160,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.16),
                        Colors.white.withOpacity(0)
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pointsLabel,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        StreamBuilder<int>(
                          stream: uid.isEmpty
                              ? const Stream<int>.empty()
                              : WalletService().watchBalance(uid),
                          builder: (context, balSnap) {
                            final points = balSnap.data ?? 0;
                            // "1 250" en gros + " pts" plus petit sur la même
                            // ligne, comme sur la maquette — pas un seul bloc
                            // de texte à taille uniforme, et le nombre est
                            // groupé par milliers (ex. "1,250"), pas un bloc
                            // de chiffres brut.
                            return Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                      text: _formatPoints(points),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800)),
                                  const TextSpan(
                                      text: " pts",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: onButtonTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: const BoxDecoration(
                              // Pastille BLANCHE PLEINE (pas translucide) —
                              // texte et flèche dans le vert profond de la
                              // carte, comme sur la maquette (la version
                              // translucide/texte blanc était une
                              // approximation, pas la bonne lecture).
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(999)),
                            ),
                            // FittedBox : certains libellés de bouton (ex.
                            // "Voir le portefeuille") sont nettement plus
                            // longs que d'autres ("Voir mon profil") — sans
                            // ça le texte déborde de la pastille sur les
                            // écrans étroits une fois la place prise par le
                            // badge trophée.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(buttonLabel,
                                      style: const TextStyle(
                                          color: AppColors.pointsCardButtonText,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 4),
                                  const Icon(RemixIcons.arrow_right_fill,
                                      color: AppColors.pointsCardButtonText,
                                      size: 13),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _TrophyWithLeaves(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Regroupe [n] par milliers avec des virgules (ex. 1250 -> "1,250"), comme
/// sur la maquette. Les soldes de points sont toujours >= 0, donc pas de
/// gestion de signe négatif.
String _formatPoints(int n) {
  final digits = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Badge de la carte "Mes points" — un cercle VERT posé sur le dégradé de
/// la carte, et le trophée doré (dégradé clair→ambré + médaillon rond) posé
/// dessus, dimensionné pour remplir le cercle.
///
/// Deux familles de feuilles (demande explicite : garder à la fois "de
/// larges feuilles" à la racine ET "ces plus petites feuilles tout autour,
/// du côté gauche au droit, en passant par le haut") : un éventail large à
/// la RACINE (bas) du cercle façon couverture/nid, ET une couronne de
/// petites feuilles qui referme le tour par le haut (gauche → sommet →
/// droite). Le trophée est agrandi et reçoit un effet "coffre au trésor" —
/// rayons dorés qui rayonnent derrière lui, halo et reflet brillant.
class _TrophyWithLeaves extends StatelessWidget {
  const _TrophyWithLeaves();

  // Un ton qui se fond dans le dégradé de la carte (feuilles "de fond") et
  // un vert franc plus clair (feuilles "de premier plan") — les deux teintes
  // de feuille mesurées sur la maquette.
  static const _backLeaf = Color(0xFF1F8F72);
  static const _frontLeaf = Color(0xFF3FB25A);

  // Grand éventail à la racine (bas) du cercle, façon couverture/nid.
  static const _largeLeaves = [
    (dx: -52.0, dy: 26.0, size: 56.0, angle: -1.0, color: _backLeaf),
    (dx: -30.0, dy: 40.0, size: 64.0, angle: -0.55, color: _frontLeaf),
    (dx: -6.0, dy: 47.0, size: 60.0, angle: -0.12, color: _backLeaf),
    (dx: 16.0, dy: 46.0, size: 62.0, angle: 0.22, color: _frontLeaf),
    (dx: 38.0, dy: 38.0, size: 56.0, angle: 0.62, color: _backLeaf),
    (dx: 55.0, dy: 22.0, size: 50.0, angle: 1.05, color: _frontLeaf),
  ];

  // Petite couronne qui ferme le tour par le haut : gauche -> sommet ->
  // droite (demande explicite).
  static const _smallLeaves = [
    (dx: -48.0, dy: -6.0, size: 25.0, angle: -1.3, color: _frontLeaf),
    (dx: -36.0, dy: -33.0, size: 27.0, angle: -0.8, color: _backLeaf),
    (dx: -13.0, dy: -48.0, size: 25.0, angle: -0.25, color: _frontLeaf),
    (dx: 13.0, dy: -48.0, size: 25.0, angle: 0.25, color: _backLeaf),
    (dx: 36.0, dy: -33.0, size: 27.0, angle: 0.8, color: _frontLeaf),
    (dx: 48.0, dy: -6.0, size: 25.0, angle: 1.3, color: _backLeaf),
  ];

  @override
  Widget build(BuildContext context) {
    const cx = 68.0, cy = 64.0; // centre du cercle dans le SizedBox ci-dessous
    return SizedBox(
      width: 136,
      height: 124,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rayons dorés en fond — effet "coffre au trésor qui s'ouvre"
          // (demande explicite), derrière tout le reste.
          Positioned(
            left: cx - 58,
            top: cy - 58,
            child: const SizedBox(
              width: 116,
              height: 116,
              child: CustomPaint(painter: _RaysPainter()),
            ),
          ),
          // Feuilles ensuite (couche du bas) : le cercle posé par-dessus
          // masque leur base, donnant l'impression qu'elles émergent de
          // derrière lui plutôt que d'être collées à côté.
          for (final leaf in [..._largeLeaves, ..._smallLeaves])
            Positioned(
              left: cx + leaf.dx - leaf.size * 0.3,
              top: cy + leaf.dy - leaf.size * 0.5,
              child: _BadgeLeaf(
                  size: leaf.size, rotation: leaf.angle, color: leaf.color),
            ),
          Positioned(
            left: cx - 37,
            top: cy - 37,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Dégradé radial (au lieu d'un aplat) + liseré clair — un
                // effet "badge" un peu plus travaillé qu'un simple disque.
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.4),
                  radius: 1.0,
                  colors: [
                    Color.lerp(AppColors.pointsCardBadge, Colors.white, 0.3)!,
                    AppColors.pointsCardBadge,
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.28), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
              ),
            ),
          ),
          // Trophée — repris À L'IDENTIQUE de la capture de référence
          // fournie par l'utilisateur (demande explicite : "do only the
          // trophee head exactly this way") : juste l'icône, en plein or,
          // SANS halo, sans reflet glossy, sans médaillon — ces ajouts ont
          // été retirés, ils ne sont pas dans la maquette.
          Positioned(
            left: cx - 28,
            top: cy - 29,
            child: const Icon(RemixIcons.trophy_fill,
                color: Color(0xFFFFC940), size: 56),
          ),
        ],
      ),
    );
  }
}

/// Feuille en lame incurvée, pointue à l'extrémité — dessinée spécifiquement
/// pour ce bouquet (indépendante du fond décoratif de l'app, voir
/// decorative_leaves.dart, qui n'utilise plus de feuilles) : asymétrique
/// (les deux bords ne suivent pas la même courbe), comme les feuilles fines
/// et incurvées de la maquette de référence — PAS une amande symétrique
/// (pointue aux deux bouts), lecture précédente qui ne correspondait pas.
class _BadgeLeaf extends StatelessWidget {
  final double size;
  final double rotation;
  final Color color;
  const _BadgeLeaf(
      {required this.size, required this.rotation, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        size: Size(size * 0.68, size),
        painter: _BadgeLeafPainter(color: color),
      ),
    );
  }
}

class _BadgeLeafPainter extends CustomPainter {
  final Color color;
  const _BadgeLeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Base arrondie en bas, un bord qui bombe peu (gauche) et un bord qui
    // bombe beaucoup (droite) avant de se rejoindre en pointe fine en haut —
    // cette asymétrie donne la courbe naturelle d'une lame de feuille, au
    // lieu d'une amande parfaitement symétrique. Les points de contrôle
    // dépassent légèrement la largeur du canevas (< 0 et > w) pour que la
    // feuille reste PLEINE (pas un fin trait) une fois réduite à sa petite
    // taille réelle sur la carte.
    final path = Path()
      ..moveTo(w * 0.5, h)
      ..quadraticBezierTo(-w * 0.08, h * 0.55, w * 0.42, 0)
      ..quadraticBezierTo(w * 1.05, h * 0.48, w * 0.5, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);

    // Nervure centrale, légère, comme sur la maquette.
    final veinPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.46, h * 0.92), Offset(w * 0.42, h * 0.15), veinPaint);
  }

  @override
  bool shouldRepaint(covariant _BadgeLeafPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Rayons dorés qui rayonnent depuis le centre du badge, comme la lumière
/// d'un coffre au trésor qui s'ouvre (demande explicite) — alternance de
/// rayons longs/courts et clairs/plus discrets pour un rendu moins
/// mécanique qu'un simple soleil régulier.
class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  static const _rayCount = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _rayCount; i++) {
      final angle = (2 * math.pi / _rayCount) * i;
      final isLong = i.isEven;
      final length = maxRadius * (isLong ? 1.0 : 0.68);
      final halfSpread = isLong ? 0.10 : 0.06;

      paint.color = const Color(0xFFFFD54F)
          .withOpacity(isLong ? 0.55 : 0.30);

      final tip1 = center +
          Offset(math.cos(angle - halfSpread) * length,
              math.sin(angle - halfSpread) * length);
      final tip2 = center +
          Offset(math.cos(angle + halfSpread) * length,
              math.sin(angle + halfSpread) * length);

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(tip1.dx, tip1.dy)
        ..lineTo(tip2.dx, tip2.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) => false;
}
