import 'package:flutter/material.dart';
import '../../core/theme.dart';

// Palette diversifiée pour les icônes d'onboarding (pas tout en vert) :
const Color _pinRed = Color(0xFFE05A3B);
const Color _pinRedDeep = Color(0xFFB8402A);
const Color _truckBody = Color(0xFF6E8299);
const Color _truckBodyDark = Color(0xFF48586B);
const Color _roadColor = Color(0xFF8FA3B0);
const Color _scaleSilver = Color(0xFFB7C0C7);
const Color _scaleSilverDark = Color(0xFF7E8A92);
const Color _giftRed = Color(0xFFE0503F);
const Color _giftRedDark = Color(0xFFB53A2C);
const Color _cardBlue = Color(0xFF3B6EA8);
const Color _cardBlueDark = Color(0xFF244A78);

/// Widgets d'illustrations animées pour l'onboarding, reproduisant les
/// séquences demandées :
/// 1. Location  : carte -> camion qui traverse -> pin final
/// 2. Weigh     : balance -> scan -> coche verte de validation
/// 3. Wallet    : cadeau/pièces découverts -> portefeuille -> pièces qui tombent dedans
/// 4. Funds     : pile de billets qui se forme -> illustration finale
///
/// Toutes les icônes sont dessinées sur mesure (CustomPainter / formes +
/// dégradés + ombres douces) — plus aucun emoji — pour un rendu cohérent
/// avec l'identité de la marque (mêmes dégradés verts que le logo), au lieu
/// du rendu "clipart" que donnaient les emojis.
///
/// Chaque widget reçoit une Animation<double> (0.0 -> 1.0, pilotée par un
/// AnimationController dans OnboardingScreen) et découpe cette progression
/// en étapes via Interval, pour enchaîner les sous-animations.

double _stage(Animation<double> t, double start, double end) {
  final v = ((t.value - start) / (end - start)).clamp(0.0, 1.0);
  return Curves.easeOutCubic.transform(v);
}

BoxShadow _softShadow({double blur = 14, double dy = 8, double opacity = 0.22}) {
  return BoxShadow(color: Colors.black.withOpacity(opacity), blurRadius: blur, offset: Offset(0, dy));
}

// ============================================================
// 1. LOCATION : carte -> camion -> pin final
// ============================================================
class AnimatedLocationIllustration extends StatelessWidget {
  final Animation<double> t;
  const AnimatedLocationIllustration({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final mapIn = _stage(t, 0.0, 0.22);
        final mapOut = 1 - _stage(t, 0.55, 0.68);
        final truckProgress = _stage(t, 0.30, 0.66);
        final truckOpacity = _stage(t, 0.28, 0.38) * (1 - _stage(t, 0.62, 0.70));
        final pinScale = _stage(t, 0.66, 1.0);
        final ringScale = _stage(t, 0.70, 1.0);

        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Carte stylisée avec route
              Opacity(
                opacity: (mapIn * mapOut).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.85 + 0.15 * mapIn,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [_softShadow(blur: 18, dy: 10, opacity: 0.10)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CustomPaint(painter: _MapPainter()),
                    ),
                  ),
                ),
              ),
              // Camion vectoriel (au lieu de l'emoji)
              if (truckOpacity > 0)
                Opacity(
                  opacity: truckOpacity,
                  child: Transform.translate(
                    offset: Offset(-130 + 260 * truckProgress, 26),
                    child: const _TruckIcon(size: 46),
                  ),
                ),
              // Anneau de pulsation + pin final
              Opacity(
                opacity: pinScale,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * ringScale,
                  child: Container(
                    width: 76,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(color: _pinRed.withOpacity(0.45), width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, -30 * pinScale),
                child: Opacity(
                  opacity: pinScale,
                  child: Transform.scale(
                    scale: 0.5 + 0.5 * pinScale,
                    alignment: Alignment.bottomCenter,
                    child: const _MapPinIcon(size: 66),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fond de carte : petits pâtés d'immeubles + route sinueuse, dessinés
/// proprement (pas une simple grille) pour un rendu carte plus crédible.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blockPaint = Paint()..color = AppColors.line.withOpacity(0.9);
    final blocks = [
      Rect.fromLTWH(14, 18, 34, 26),
      Rect.fromLTWH(60, 14, 22, 40),
      Rect.fromLTWH(size.width - 60, 22, 30, 24),
      Rect.fromLTWH(size.width - 34, 100, 24, 30),
      Rect.fromLTWH(20, 120, 26, 22),
      Rect.fromLTWH(70, 140, 30, 18),
    ];
    for (final b in blocks) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(4)), blockPaint);
    }

    final roadPaint = Paint()
      ..color = _roadColor.withOpacity(0.55)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(6, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.55, size.width * 0.5, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.7, size.width - 6, size.height * 0.5);
    canvas.drawPath(path, roadPaint);

    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2;
    canvas.drawPath(
      dashPath(path, dashArray: [6, 6]),
      dashPaint..style = PaintingStyle.stroke,
    );
  }

  Path dashPath(Path source, {required List<double> dashArray}) {
    final Path dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      int i = 0;
      while (distance < metric.length) {
        final len = dashArray[i % dashArray.length];
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
        i++;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Camionnette de collecte dessinée sur mesure (dégradé vert, roues, vitre).
class _TruckIcon extends StatelessWidget {
  final double size;
  const _TruckIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.72,
      child: CustomPaint(painter: _TruckPainter()),
    );
  }
}

class _TruckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = Rect.fromLTWH(0, size.height * 0.18, size.width * 0.62, size.height * 0.5);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_truckBody, _truckBodyDark],
      ).createShader(bodyRect);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(5)), bodyPaint);

    // Cabine
    final cabPath = Path()
      ..moveTo(bodyRect.right, size.height * 0.68)
      ..lineTo(bodyRect.right, size.height * 0.30)
      ..lineTo(size.width * 0.78, size.height * 0.30)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.68)
      ..close();
    canvas.drawPath(cabPath, Paint()..color = _truckBodyDark);

    // Vitre
    final windowPath = Path()
      ..moveTo(size.width * 0.80, size.height * 0.36)
      ..lineTo(size.width * 0.94, size.height * 0.50)
      ..lineTo(size.width * 0.80, size.height * 0.50)
      ..close();
    canvas.drawPath(windowPath, Paint()..color = Colors.white.withOpacity(0.85));

    // Roues
    final wheelPaint = Paint()..color = const Color(0xFF2E3742);
    final hubPaint = Paint()..color = Colors.white.withOpacity(0.9);
    for (final cx in [size.width * 0.18, size.width * 0.82]) {
      final c = Offset(cx, size.height * 0.68);
      canvas.drawCircle(c, size.height * 0.16, wheelPaint);
      canvas.drawCircle(c, size.height * 0.06, hubPaint);
    }

    // Petit symbole recyclage sur la benne
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(size.width * 0.28, size.height * 0.40), 7, iconPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pin de localisation en forme de goutte, dégradé + reflet + ombre portée.
class _MapPinIcon extends StatelessWidget {
  final double size;
  const _MapPinIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.25,
      child: CustomPaint(painter: _PinPainter()),
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, h)
      ..cubicTo(w * 0.1, h * 0.65, 0, h * 0.42, 0, h * 0.36)
      ..arcToPoint(Offset(w, h * 0.36), radius: Radius.circular(w / 2), clockwise: true)
      ..cubicTo(w, h * 0.42, w * 0.9, h * 0.65, w / 2, h)
      ..close();

    canvas.drawShadow(path.shift(const Offset(0, 3)), Colors.black.withOpacity(0.35), 4, false);

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_pinRed, _pinRedDeep],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, paint);

    canvas.drawCircle(Offset(w / 2, h * 0.36), w * 0.24, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w / 2, h * 0.36), w * 0.24,
        Paint()..color = _pinRedDeep.withOpacity(0.25)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// 2. WEIGH & VERIFY : balance -> scan -> coche
// ============================================================
class AnimatedWeighIllustration extends StatelessWidget {
  final Animation<double> t;
  const AnimatedWeighIllustration({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final iconIn = _stage(t, 0.0, 0.25);
        final scanRaw = _stage(t, 0.22, 0.62);
        final scanY = (scanRaw <= 0.5 ? scanRaw * 2 : (scanRaw - 0.5) * 2);
        final scanVisible = t.value > 0.22 && t.value < 0.64;
        final tickIn = _stage(t, 0.64, 1.0);

        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: iconIn,
                child: Transform.scale(
                  scale: 0.8 + 0.2 * iconIn,
                  child: Container(
                    width: 156,
                    height: 156,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [_softShadow(blur: 18, dy: 10, opacity: 0.10)],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: const _ScaleIcon(),
                  ),
                ),
              ),
              if (scanVisible)
                Positioned(
                  top: 32 + 148 * scanY,
                  child: Container(
                    width: 156,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(colors: [
                        AppColors.greenBright.withOpacity(0),
                        AppColors.greenBright,
                        AppColors.greenBright.withOpacity(0),
                      ]),
                      boxShadow: [
                        BoxShadow(color: AppColors.greenBright.withOpacity(0.6), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              if (tickIn > 0)
                Positioned(
                  bottom: 34,
                  right: 40,
                  child: Transform.scale(
                    scale: Curves.elasticOut.transform(tickIn),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        shape: BoxShape.circle,
                        boxShadow: [_softShadow(blur: 10, dy: 4, opacity: 0.3)],
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Balance à plateaux dessinée sur mesure (pied + fléau + deux plateaux).
class _ScaleIcon extends StatelessWidget {
  const _ScaleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScalePainter(), size: const Size(100, 100));
  }
}

/// Balance à plateaux redessinée : formes PLEINES (pas juste des contours),
/// dégradés argentés, ombres portées et plateaux bien visibles — plus
/// attractive que la version filiforme précédente.
class _ScalePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final silverGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_scaleSilver, _scaleSilverDark],
    );

    // Ombre portée douce au sol
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, size.height - 6), width: 46, height: 8),
      Paint()..color = Colors.black.withOpacity(0.14),
    );

    // Base (trapèze plein)
    final basePath = Path()
      ..moveTo(cx - 20, size.height - 10)
      ..lineTo(cx + 20, size.height - 10)
      ..lineTo(cx + 9, size.height - 20)
      ..lineTo(cx - 9, size.height - 20)
      ..close();
    canvas.drawPath(
      basePath,
      Paint()..shader = silverGradient.createShader(Rect.fromLTWH(0, size.height - 20, size.width, 20)),
    );

    // Pied (rectangle arrondi plein)
    final pillarRect = Rect.fromLTWH(cx - 4, 16, 8, size.height - 34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillarRect, const Radius.circular(4)),
      Paint()..shader = silverGradient.createShader(pillarRect),
    );

    // Fléau horizontal (rectangle arrondi plein, légèrement plus épais)
    final beamRect = Rect.fromLTWH(4, 20, size.width - 8, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(beamRect, const Radius.circular(3)),
      Paint()..shader = silverGradient.createShader(beamRect),
    );

    // Chaînes fines vers les plateaux
    final chainPaint = Paint()
      ..color = _scaleSilverDark
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final panY = size.height * 0.58;
    canvas.drawLine(Offset(10, 24), Offset(16, panY), chainPaint);
    canvas.drawLine(Offset(size.width - 10, 24), Offset(size.width - 16, panY), chainPaint);

    // Plateaux PLEINS (ellipses avec reflet, pas juste un contour)
    void drawPan(double x) {
      final panRect = Rect.fromCenter(center: Offset(x, panY), width: 34, height: 15);
      canvas.drawShadow(Path()..addOval(panRect.translate(0, 3)), Colors.black.withOpacity(0.3), 3, false);
      canvas.drawOval(panRect, Paint()..shader = silverGradient.createShader(panRect));
      // reflet
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x - 6, panY - 3), width: 12, height: 5),
        Paint()..color = Colors.white.withOpacity(0.55),
      );
    }

    drawPan(16);
    drawPan(size.width - 16);

    // Sommet (petite sphère décorative)
    canvas.drawCircle(Offset(cx, 12), 6, Paint()..shader = silverGradient.createShader(Rect.fromCircle(center: Offset(cx, 12), radius: 6)));
    canvas.drawCircle(Offset(cx - 2, 10), 2, Paint()..color = Colors.white.withOpacity(0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// 3. WALLET : cadeau -> portefeuille -> pièces qui tombent
// ============================================================
class AnimatedWalletIllustration extends StatelessWidget {
  final Animation<double> t;
  const AnimatedWalletIllustration({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final giftIn = _stage(t, 0.0, 0.22);
        final giftOut = 1 - _stage(t, 0.26, 0.34);
        final walletIn = _stage(t, 0.30, 0.55);
        final coin1 = _stage(t, 0.55, 0.78);
        final coin2 = _stage(t, 0.63, 0.86);
        final coin3 = _stage(t, 0.71, 0.94);

        Widget fallingCoin(double progress, double dx) {
          if (progress <= 0) return const SizedBox.shrink();
          final y = -90 + 160 * progress;
          final opacity = progress < 0.85 ? 1.0 : (1 - (progress - 0.85) / 0.15);
          return Positioned(
            top: 60 + y,
            left: 110 + dx,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: const _CoinIcon(size: 22),
            ),
          );
        }

        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (giftIn * giftOut > 0)
                Opacity(
                  opacity: (giftIn * giftOut).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: Curves.elasticOut.transform(giftIn),
                    child: const _GiftIcon(size: 74),
                  ),
                ),
              if (walletIn > 0)
                Opacity(
                  opacity: walletIn,
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * walletIn,
                    child: const _BrownWalletIcon(),
                  ),
                ),
              fallingCoin(coin1, -22),
              fallingCoin(coin2, 4),
              fallingCoin(coin3, 26),
            ],
          ),
        );
      },
    );
  }
}

/// Pièce dorée avec dégradé et reflet — remplace l'emoji 🪙.
class _CoinIcon extends StatelessWidget {
  final double size;
  const _CoinIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6D583), Color(0xFFD8A857)],
        ),
        border: Border.all(color: const Color(0xFFB9863A), width: 1.2),
        boxShadow: [_softShadow(blur: 6, dy: 2, opacity: 0.25)],
      ),
      alignment: Alignment.center,
      child: Icon(Icons.eco, size: size * 0.5, color: const Color(0xFF8A5A1E)),
    );
  }
}

/// Cadeau (boîte + ruban) dessiné sur mesure — remplace l'emoji 🎁.
class _GiftIcon extends StatelessWidget {
  final double size;
  const _GiftIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _GiftPainter()));
  }
}

class _GiftPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boxRect = Rect.fromLTWH(size.width * 0.08, size.height * 0.38, size.width * 0.84, size.height * 0.54);
    final boxPaint = Paint()
      ..shader = const LinearGradient(colors: [_giftRed, _giftRedDark])
          .createShader(boxRect);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(6)), boxPaint..style = PaintingStyle.fill);

    final lidRect = Rect.fromLTWH(size.width * 0.02, size.height * 0.28, size.width * 0.96, size.height * 0.14);
    canvas.drawRRect(RRect.fromRectAndRadius(lidRect, const Radius.circular(5)), Paint()..color = _giftRedDark);

    final ribbonPaint = Paint()..color = const Color(0xFFD8A857);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.44, size.height * 0.28, size.width * 0.12, size.height * 0.64), ribbonPaint);

    final bowPath = Path()
      ..moveTo(size.width / 2, size.height * 0.28)
      ..cubicTo(size.width * 0.2, size.height * 0.02, size.width * 0.06, size.height * 0.18, size.width / 2, size.height * 0.28)
      ..moveTo(size.width / 2, size.height * 0.28)
      ..cubicTo(size.width * 0.8, size.height * 0.02, size.width * 0.94, size.height * 0.18, size.width / 2, size.height * 0.28);
    canvas.drawPath(bowPath, ribbonPaint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------- Portefeuille bifold brun (masculin) ----------------
class _BrownWalletIcon extends StatelessWidget {
  const _BrownWalletIcon();

  static const Color leather = Color(0xFF6B4226);
  static const Color leatherDark = Color(0xFF4E2F1B);
  static const Color stitching = Color(0xFF8A6844);
  static const Color goldButton = Color(0xFFD8A857);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 66,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7A4E2E), leather],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: leatherDark.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))],
            ),
          ),
          Positioned(
            left: 4,
            right: 4,
            top: 31,
            child: Container(height: 2, color: leatherDark.withOpacity(0.6)),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: Row(
              children: List.generate(
                10,
                (i) => Expanded(
                  child: Container(
                    height: 1.4,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    color: stitching.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 22,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: goldButton,
                shape: BoxShape.circle,
                boxShadow: [_softShadow(blur: 3, dy: 1, opacity: 0.3)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 4. MONEY PILE -> FUNDS
// ============================================================
class AnimatedFundsIllustration extends StatelessWidget {
  final Animation<double> t;
  const AnimatedFundsIllustration({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final note1 = _stage(t, 0.0, 0.20);
        final note2 = _stage(t, 0.14, 0.34);
        final note3 = _stage(t, 0.28, 0.48);
        final note4 = _stage(t, 0.42, 0.62);
        final finalIn = _stage(t, 0.62, 1.0);

        Widget note(double progress, double bottomOffset, double rotation) {
          if (progress <= 0) return const SizedBox.shrink();
          return Positioned(
            bottom: 30 + bottomOffset,
            child: Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - progress)),
                child: Transform.rotate(
                  angle: rotation * (1 - progress) * 0.3,
                  child: Container(
                    width: 112,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
                      boxShadow: [_softShadow(blur: 6, dy: 3, opacity: 0.18)],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.4),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.eco, size: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              note(note1, 0, -1),
              note(note2, 18, 1),
              note(note3, 36, -1),
              note(note4, 54, 1),
              if (finalIn > 0)
                Positioned(
                  top: 6,
                  child: Opacity(
                    opacity: finalIn,
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * finalIn,
                      child: const _CardIcon(size: 64),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Carte de paiement dessinée sur mesure (dégradé + puce) — remplace 💳.
class _CardIcon extends StatelessWidget {
  final double size;
  const _CardIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardBlueDark, _cardBlue],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [_softShadow(blur: 10, dy: 5, opacity: 0.25)],
      ),
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: size * 0.18,
            height: size * 0.14,
            decoration: BoxDecoration(
              color: const Color(0xFFD8A857),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Spacer(),
          Container(width: size * 0.5, height: 3, color: Colors.white.withOpacity(0.85)),
          const SizedBox(height: 4),
          Container(width: size * 0.3, height: 3, color: Colors.white.withOpacity(0.6)),
        ],
      ),
    );
  }
}
