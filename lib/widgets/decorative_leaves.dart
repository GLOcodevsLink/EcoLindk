import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Feuilles décoratives flottantes, à superposer en arrière-plan de n'importe
/// quel écran pour reproduire l'ambiance "nature / recyclage" de la maquette
/// (utilisées sur Login, Register, Home...).
///
/// Utilisation : enveloppe le contenu de l'écran dans un Stack, et place
/// `const DecorativeLeaves()` en premier enfant (donc en dessous du reste).
class DecorativeLeaves extends StatelessWidget {
  /// Variante plus discrète (moins de feuilles, plus petites) pour les
  /// écrans avec beaucoup de contenu (formulaires notamment).
  final bool subtle;

  const DecorativeLeaves({super.key, this.subtle = false});

  @override
  Widget build(BuildContext context) {
    final opacity = subtle ? 0.5 : 0.85;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -10,
            right: -14,
            child: _Leaf(size: subtle ? 46 : 62, rotation: -0.4, opacity: opacity),
          ),
          Positioned(
            top: 60,
            left: -18,
            child: _Leaf(size: subtle ? 34 : 44, rotation: 0.6, opacity: opacity * 0.8, color: AppColors.greenBright),
          ),
          if (!subtle) ...[
            Positioned(
              bottom: 120,
              right: -10,
              child: _Leaf(size: 36, rotation: 1.1, opacity: 0.6, color: AppColors.greenMid),
            ),
            Positioned(
              top: 140,
              right: 10,
              child: _Butterfly(size: 26, opacity: 0.75),
            ),
          ],
        ],
      ),
    );
  }
}

class _Leaf extends StatelessWidget {
  final double size;
  final double rotation;
  final double opacity;
  final Color color;

  const _Leaf({
    required this.size,
    required this.rotation,
    required this.opacity,
    this.color = AppColors.greenMid,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: rotation,
        child: CustomPaint(
          size: Size(size, size * 0.7),
          painter: _LeafPainter(color: color),
        ),
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  final Color color;
  const _LeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.3, 0, size.width, size.height * 0.15);
    path.quadraticBezierTo(size.width * 0.55, size.height * 0.35, 0, size.height * 0.6);
    path.close();
    canvas.drawPath(path, paint);

    final veinPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.5),
      Offset(size.width * 0.85, size.height * 0.2),
      veinPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LeafPainter oldDelegate) => oldDelegate.color != color;
}

class _Butterfly extends StatelessWidget {
  final double size;
  final double opacity;
  const _Butterfly({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ButterflyPainter()),
      ),
    );
  }
}

class _ButterflyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wingPaint = Paint()..color = const Color(0xFFF5A623);
    final w = size.width;
    final h = size.height;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.32, h * 0.38), width: w * 0.34, height: h * 0.5), wingPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.68, h * 0.38), width: w * 0.34, height: h * 0.5), wingPaint..color = const Color(0xFFF7B84B));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.36, h * 0.68), width: w * 0.22, height: h * 0.32), wingPaint..color = const Color(0xFFF5A623));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.64, h * 0.68), width: w * 0.22, height: h * 0.32), wingPaint..color = const Color(0xFFF7B84B));
    final bodyPaint = Paint()..color = const Color(0xFF3A2A1A);
    canvas.drawLine(Offset(w * 0.5, h * 0.15), Offset(w * 0.5, h * 0.85), bodyPaint..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _ButterflyPainter oldDelegate) => false;
}
