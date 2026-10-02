import 'package:flutter/material.dart';
import '../models/collection_request.dart';

/// Illustration plate d'une catégorie de déchet (bouteille, carton, bocal,
/// boîte de conserve, canette), dessinée en vectoriel — demande explicite :
/// les pastilles de catégorie doivent montrer "une image de la catégorie",
/// pas un simple disque de couleur. Même style plat que les illustrations
/// de assets/images/howitworks_*.png ; nette à toutes les tailles, sans
/// fichier image à embarquer. Se dessine dans un carré, en tons clairs pour
/// ressortir sur le dégradé de la catégorie (voir [WasteCategoryBadge]).
class WasteCategoryArt extends StatelessWidget {
  final WasteCategory category;
  final double size;
  const WasteCategoryArt({super.key, required this.category, required this.size});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ArtPainter(category));
}

class _ArtPainter extends CustomPainter {
  final WasteCategory category;
  _ArtPainter(this.category);

  static const _white = Color(0xFFFFFFFF);
  static const _cream = Color(0xFFFFF6DE);
  static const _gold = Color(0xFFF2C94C);

  /// Teinte foncée de la catégorie, pour les détails (étiquettes, rubans).
  Color get _ink => Color.lerp(category.color, Colors.black, 0.25)!;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height); // coordonnées de 0 à 1
    switch (category) {
      case WasteCategory.plastic:
        _bottle(canvas);
      case WasteCategory.paperCardboard:
        _box(canvas);
      case WasteCategory.glass:
        _jar(canvas);
      case WasteCategory.metal:
        _tin(canvas);
      case WasteCategory.beverageCans:
        _can(canvas);
    }
    canvas.restore();
  }

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  RRect _rr(double l, double t, double r, double b, double radius) =>
      RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));

  /// Plastique : bouteille avec bouchon doré et étiquette.
  void _bottle(Canvas c) {
    final body = Path()
      ..moveTo(0.45, 0.24)
      ..lineTo(0.55, 0.24)
      ..lineTo(0.55, 0.31)
      ..cubicTo(0.63, 0.35, 0.65, 0.40, 0.65, 0.46)
      ..lineTo(0.65, 0.80)
      ..quadraticBezierTo(0.65, 0.86, 0.59, 0.86)
      ..lineTo(0.41, 0.86)
      ..quadraticBezierTo(0.35, 0.86, 0.35, 0.80)
      ..lineTo(0.35, 0.46)
      ..cubicTo(0.35, 0.40, 0.37, 0.35, 0.45, 0.31)
      ..close();
    c.drawPath(body, _fill(_white));
    c.drawRRect(_rr(0.43, 0.14, 0.57, 0.24, 0.025), _fill(_gold));
    c.drawRect(const Rect.fromLTRB(0.35, 0.54, 0.65, 0.68), _fill(category.color.withValues(alpha: 0.55)));
    c.drawLine(const Offset(0.41, 0.44), const Offset(0.41, 0.50), _stroke(category.color.withValues(alpha: 0.35), 0.03));
    c.drawLine(const Offset(0.41, 0.72), const Offset(0.41, 0.80), _stroke(category.color.withValues(alpha: 0.35), 0.03));
  }

  /// Papier/carton : carton en perspective, rabats et ruban adhésif.
  void _box(Canvas c) {
    final front = Path()
      ..moveTo(0.20, 0.44)
      ..lineTo(0.66, 0.44)
      ..lineTo(0.66, 0.82)
      ..lineTo(0.20, 0.82)
      ..close();
    final side = Path()
      ..moveTo(0.66, 0.44)
      ..lineTo(0.82, 0.32)
      ..lineTo(0.82, 0.70)
      ..lineTo(0.66, 0.82)
      ..close();
    final top = Path()
      ..moveTo(0.20, 0.44)
      ..lineTo(0.36, 0.32)
      ..lineTo(0.82, 0.32)
      ..lineTo(0.66, 0.44)
      ..close();
    c.drawPath(side, _fill(Color.lerp(_cream, category.color, 0.35)!));
    c.drawPath(front, _fill(_cream));
    c.drawPath(top, _fill(_white));
    // Ruban adhésif sur le dessus et le haut de la face avant.
    final tape = _fill(category.color.withValues(alpha: 0.75));
    c.drawPath(
        Path()
          ..moveTo(0.43, 0.44)
          ..lineTo(0.59, 0.32)
          ..lineTo(0.65, 0.32)
          ..lineTo(0.49, 0.44)
          ..close(),
        tape);
    c.drawRect(const Rect.fromLTRB(0.43, 0.44, 0.49, 0.56), tape);
    // Symbole "haut" (deux flèches) sur la face avant.
    final arrows = _stroke(_ink.withValues(alpha: 0.55), 0.025);
    for (final x in [0.28, 0.35]) {
      c.drawLine(Offset(x, 0.76), Offset(x, 0.64), arrows);
      c.drawLine(Offset(x - 0.025, 0.67), Offset(x, 0.64), arrows);
      c.drawLine(Offset(x + 0.025, 0.67), Offset(x, 0.64), arrows);
    }
  }

  /// Verre : bocal translucide à couvercle doré, avec reflets.
  void _jar(Canvas c) {
    final body = _rr(0.30, 0.34, 0.70, 0.86, 0.10);
    c.drawRRect(body, _fill(_white.withValues(alpha: 0.55)));
    c.drawRRect(body, _stroke(_white, 0.035));
    // Contenu vert au fond du bocal.
    c.save();
    c.clipRRect(body);
    c.drawRect(const Rect.fromLTRB(0.30, 0.66, 0.70, 0.86), _fill(category.color.withValues(alpha: 0.45)));
    c.restore();
    c.drawRRect(_rr(0.34, 0.27, 0.66, 0.34, 0.02), _fill(_white));
    c.drawRRect(_rr(0.32, 0.18, 0.68, 0.28, 0.035), _fill(_gold));
    final shine = _stroke(_white, 0.035);
    c.drawLine(const Offset(0.38, 0.44), const Offset(0.38, 0.60), shine);
    c.drawLine(const Offset(0.38, 0.66), const Offset(0.38, 0.70), shine);
  }

  /// Métal : boîte de conserve cerclée, avec étiquette.
  void _tin(Canvas c) {
    const steel = Color(0xFFE6EBEE);
    const steelDark = Color(0xFFB9C3CA);
    c.drawRect(const Rect.fromLTRB(0.26, 0.34, 0.74, 0.78), _fill(steel));
    c.drawOval(const Rect.fromLTRB(0.26, 0.72, 0.74, 0.84), _fill(steel));
    c.drawRect(const Rect.fromLTRB(0.26, 0.44, 0.74, 0.68), _fill(_gold));
    c.drawOval(const Rect.fromLTRB(0.26, 0.28, 0.74, 0.40), _fill(_white));
    c.drawOval(const Rect.fromLTRB(0.31, 0.30, 0.69, 0.38), _stroke(steelDark, 0.02));
    // Étiquette : petite feuille de la couleur de la catégorie.
    final leaf = Path()
      ..moveTo(0.44, 0.61)
      ..quadraticBezierTo(0.44, 0.49, 0.58, 0.50)
      ..quadraticBezierTo(0.58, 0.61, 0.44, 0.61)
      ..close();
    c.drawPath(leaf, _fill(_ink));
    final ridge = _stroke(steelDark, 0.018);
    c.drawLine(const Offset(0.26, 0.72), const Offset(0.74, 0.72), ridge);
  }

  /// Canettes : canette élancée, bandeau coloré et languette.
  void _can(Canvas c) {
    final body = Path()
      ..moveTo(0.40, 0.18)
      ..lineTo(0.60, 0.18)
      ..lineTo(0.64, 0.26)
      ..lineTo(0.64, 0.80)
      ..quadraticBezierTo(0.64, 0.86, 0.58, 0.86)
      ..lineTo(0.42, 0.86)
      ..quadraticBezierTo(0.36, 0.86, 0.36, 0.80)
      ..lineTo(0.36, 0.26)
      ..close();
    c.drawPath(body, _fill(_white));
    c.save();
    c.clipPath(body);
    c.drawRect(const Rect.fromLTRB(0.30, 0.42, 0.70, 0.66), _fill(_gold));
    c.drawRect(const Rect.fromLTRB(0.30, 0.48, 0.70, 0.60), _fill(category.color.withValues(alpha: 0.8)));
    c.restore();
    c.drawOval(const Rect.fromLTRB(0.40, 0.15, 0.60, 0.21), _fill(const Color(0xFFD9E0E4)));
    c.drawOval(const Rect.fromLTRB(0.47, 0.16, 0.55, 0.20), _stroke(const Color(0xFF9AA6AE), 0.015));
    c.drawLine(const Offset(0.41, 0.30), const Offset(0.41, 0.38), _stroke(category.color.withValues(alpha: 0.35), 0.03));
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.category != category;
}
