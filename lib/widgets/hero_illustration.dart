import 'package:flutter/material.dart';

/// Illustration principale du Landing Page.
///
/// Utilise `assets/images/landing_hero.png` — l'illustration fournie par
/// l'utilisateur (scène de gestion des déchets/recyclage). Affichée à son
/// ratio d'aspect EXACT (1811:1206, calculé depuis le fichier original) via
/// AspectRatio, donc l'image n'est jamais étirée ni recadrée : la largeur
/// s'adapte à l'écran et la hauteur suit automatiquement en conservant les
/// proportions parfaites de l'image d'origine.
///
/// COMMENT CHANGER CETTE IMAGE : remplace `assets/images/landing_hero.png`
/// par ton propre fichier. Si son ratio largeur/hauteur est différent,
/// mets à jour la constante `_aspectRatio` ci-dessous (largeur ÷ hauteur
/// de ton image en pixels) pour un rendu sans déformation ni recadrage.
class HeroIllustration extends StatelessWidget {
  const HeroIllustration({super.key});

  static const double _aspectRatio = 1536 / 689;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Image.asset(
          'assets/images/landing_hero.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
