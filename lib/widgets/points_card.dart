import 'package:flutter/material.dart';
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
                                  const Icon(Icons.arrow_forward,
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

/// Badge de la carte "Mes points" — reproduit la maquette de référence
/// (mesurée par échantillonnage direct de ses pixels, voir la doc de
/// [AppColors.pointsCardGradient]) : un cercle VERT posé sur le dégradé de
/// la carte, une couronne de feuilles en lame (pointues, incurvées — pas des
/// amandes symétriques) qui l'ENTOURE COMPLÈTEMENT comme un bouquet de fond,
/// et le trophée doré (dégradé clair→ambré + médaillon rond) posé dessus,
/// dimensionné pour remplir le cercle comme sur la référence.
///
/// Feuilles agrandies et reparties tout autour du cercle (demande explicite :
/// "put the leaves bigger and all around as a background of the trophy...
/// look well at the prototype") — couvrent maintenant aussi le côté gauche
/// (complètement absent d'une itération précédente, trop resserrée), pour
/// un vrai bouquet en couronne plutôt qu'un simple accent haut/droite.
class _TrophyWithLeaves extends StatelessWidget {
  const _TrophyWithLeaves();

  // Un ton qui se fond dans le dégradé de la carte (feuilles "de fond") et
  // un vert franc plus clair (feuilles "de premier plan") — les deux teintes
  // de feuille mesurées sur la maquette.
  static const _backLeaf = Color(0xFF1F8F72);
  static const _frontLeaf = Color(0xFF3FB25A);

  // Chaque feuille : décalage depuis le centre du cercle (dx, dy), taille,
  // angle et teinte. Couronne COMPLÈTE tout autour du cercle (haut, droite,
  // bas, gauche) — pas juste un bouquet en haut, comme sur la maquette.
  static const _leaves = [
    // Groupe du haut (feuilles "de fond", en éventail).
    (dx: -23.0, dy: -53.0, size: 39.0, angle: -0.35, color: _backLeaf),
    (dx: 2.0, dy: -60.0, size: 41.0, angle: 0.0, color: _backLeaf),
    (dx: 28.0, dy: -53.0, size: 37.0, angle: 0.4, color: _backLeaf),
    // Côté droit.
    (dx: 48.0, dy: -30.0, size: 30.0, angle: 0.85, color: _frontLeaf),
    (dx: 55.0, dy: 2.0, size: 25.0, angle: 1.3, color: _backLeaf),
    (dx: 48.0, dy: 30.0, size: 25.0, angle: 1.7, color: _frontLeaf),
    // Bas.
    (dx: 16.0, dy: 52.0, size: 30.0, angle: 2.2, color: _frontLeaf),
    (dx: -21.0, dy: 48.0, size: 35.0, angle: -1.8, color: _backLeaf),
    // Côté gauche — pour boucler la couronne (manquait avant).
    (dx: -48.0, dy: 7.0, size: 34.0, angle: -1.3, color: _frontLeaf),
    (dx: -46.0, dy: -26.0, size: 27.0, angle: -0.9, color: _backLeaf),
  ];

  @override
  Widget build(BuildContext context) {
    const cx = 64.0, cy = 62.0; // centre du cercle dans le SizedBox ci-dessous
    return SizedBox(
      width: 129,
      height: 115,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Feuilles d'abord (couche du bas) : le cercle posé par-dessus
          // masque leur base, donnant l'impression qu'elles émergent de
          // derrière lui plutôt que d'être collées à côté.
          for (final leaf in _leaves)
            Positioned(
              left: cx + leaf.dx - leaf.size * 0.3,
              top: cy + leaf.dy - leaf.size * 0.5,
              child: _BadgeLeaf(
                  size: leaf.size, rotation: leaf.angle, color: leaf.color),
            ),
          Positioned(
            left: cx - 33,
            top: cy - 33,
            child: Container(
              width: 66,
              height: 66,
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
          // Trophée agrandi (48, contre 38 avant) pour remplir le cercle
          // presque bord à bord, comme sur la maquette.
          Positioned(
            left: cx - 24,
            top: cy - 25,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [Color(0xFFFFE38A), Color(0xFFE8A317)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(rect),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 48),
                  ),
                  // Médaillon rond au centre de la coupe, comme sur la
                  // maquette (pas un losange).
                  Positioned(
                    top: 17,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
