import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Éléments décoratifs flottants (poubelles de recyclage), à superposer en
/// arrière-plan de n'importe quel écran pour reproduire l'ambiance
/// "nature / recyclage" de la maquette (utilisées sur Login, Register,
/// Home...).
///
/// Remplace l'ancien motif "feuilles" (demande explicite : les pages étaient
/// "un peu trop vides", et le motif de fond devait plutôt évoquer le
/// recyclage — poubelles/tri — qu'une feuille générique) — MÊMES positions
/// et MÊMES tailles qu'avant, seul le dessin change, pour ne pas revoir toute
/// la mise en page des ~25 écrans qui l'utilisent.
///
/// Utilisation : enveloppe le contenu de l'écran dans un Stack, et place
/// `const DecorativeLeaves()` en premier enfant (donc en dessous du reste).
class DecorativeLeaves extends StatelessWidget {
  /// Variante plus discrète (moins d'éléments, plus petits) pour les
  /// écrans avec beaucoup de contenu (formulaires notamment).
  final bool subtle;

  const DecorativeLeaves({super.key, this.subtle = false});

  @override
  Widget build(BuildContext context) {
    // Nettement rehaussé (demande explicite : "the decoration should be
    // more visible") — les poubelles se distinguaient à peine du fond,
    // surtout en variante `subtle`, presque invisibles sur les écrans de
    // formulaire. Tailles et opacités toutes relevées d'un cran, et les
    // bords rognés (offsets négatifs) resserrés pour qu'on en voie
    // davantage plutôt que la moitié hors-cadre.
    final opacity = subtle ? 0.75 : 0.95;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -4,
            right: -6,
            child:
                _Bin(size: subtle ? 60 : 80, rotation: -0.4, opacity: opacity),
          ),
          Positioned(
            top: 64,
            left: -8,
            child: _Bin(
                size: subtle ? 46 : 58,
                rotation: 0.6,
                opacity: opacity * 0.9,
                color: AppColors.greenBright),
          ),
          if (!subtle) ...[
            Positioned(
              bottom: 130,
              right: -2,
              child: _Bin(
                  size: 48,
                  rotation: 1.1,
                  opacity: 0.78,
                  color: AppColors.greenMid),
            ),
            Positioned(
              top: 150,
              right: 14,
              child: _RecycleSymbol(size: 34, opacity: 0.85),
            ),
            Positioned(
              bottom: 30,
              left: -6,
              child: _Bin(
                  size: 38,
                  rotation: -0.9,
                  opacity: 0.7,
                  color: AppColors.greenDark),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bin extends StatelessWidget {
  final double size;
  final double rotation;
  final double opacity;
  final Color color;

  const _Bin({
    required this.size,
    required this.rotation,
    required this.opacity,
    this.color = AppColors.greenMid,
  });

  @override
  Widget build(BuildContext context) {
    return DecoBin(size: size, rotation: rotation, opacity: opacity, color: color);
  }
}

/// Silhouette de poubelle de recyclage (couvercle + poignée + corps évasé +
/// cannelures) utilisée en fond d'écran par [DecorativeLeaves] — enrichie
/// (demande explicite : "if there is a way beautify those dustbins more")
/// avec un dégradé de volume (au lieu d'un aplat plat), une ombre portée
/// douce (effet "autocollant qui flotte" plutôt que posé à plat) et un petit
/// pictogramme de recyclage semi-transparent sur le corps, plutôt qu'une
/// simple silhouette monochrome.
class DecoBin extends StatelessWidget {
  final double size;
  final double rotation;
  final double opacity;
  final Color color;

  const DecoBin({
    super.key,
    required this.size,
    this.rotation = 0,
    this.opacity = 1,
    this.color = AppColors.greenMid,
  });

  @override
  Widget build(BuildContext context) {
    final w = size * 0.66, h = size;
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: rotation,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(size: Size(w, h), painter: _BinPainter(color: color)),
              // Petit pictogramme de recyclage sur le corps — seulement si
              // la poubelle est assez grande pour rester lisible, sinon un
              // simple pâté flou de pixels.
              if (size >= 40)
                Positioned(
                  top: h * 0.42,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Icon(Icons.recycling_rounded,
                        size: w * 0.5, color: Colors.white.withOpacity(0.55)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BinPainter extends CustomPainter {
  final Color color;
  const _BinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Poignée du couvercle.
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.38, 0, w * 0.62, h * 0.09),
      Radius.circular(w * 0.06),
    );

    // Couvercle, légèrement plus large que le corps.
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, h * 0.1, w, h * 0.22),
      Radius.circular(w * 0.08),
    );

    // Corps évasé (plus étroit en bas), coins bas arrondis.
    final body = Path()
      ..moveTo(w * 0.1, h * 0.28)
      ..lineTo(w * 0.9, h * 0.28)
      ..lineTo(w * 0.78, h * 0.94)
      ..quadraticBezierTo(w * 0.76, h, w * 0.7, h)
      ..lineTo(w * 0.3, h)
      ..quadraticBezierTo(w * 0.24, h, w * 0.22, h * 0.94)
      ..close();

    // Dégradé clair (haut) -> plus soutenu (bas) plutôt qu'un aplat plat —
    // donne un peu de volume, comme un plastique moulé.
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.white, 0.25)!,
          color,
          Color.lerp(color, Colors.black, 0.16)!,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(handle, fillPaint);
    canvas.drawRRect(lid, fillPaint);
    canvas.drawPath(body, fillPaint);

    // Liseré clair sur le bord gauche du corps — suggère un reflet, comme un
    // plastique légèrement brillant plutôt qu'un aplat mat.
    final sheen = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.17, h * 0.34), Offset(w * 0.13, h * 0.86), sheen);

    // Cannelures blanches (relief du corps) — trois plutôt que deux, pour
    // un rendu plus régulier/"moulé".
    final groove = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    for (final gx in [0.40, 0.5, 0.60]) {
      canvas.drawLine(Offset(w * gx, h * 0.38), Offset(w * gx, h * 0.86), groove);
    }
  }

  @override
  bool shouldRepaint(covariant _BinPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Petit symbole "flèches de recyclage" — remplace l'ancien papillon
/// (décoratif mais sans rapport avec le recyclage) pour rester dans le
/// thème demandé sur tout élément de fond.
class _RecycleSymbol extends StatelessWidget {
  final double size;
  final double opacity;
  const _RecycleSymbol({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Icon(Icons.recycling_rounded, size: size, color: AppColors.greenDeep),
    );
  }
}
