import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Logo officiel EcoLindk.
///
/// Le fichier `assets/images/logo.png` contient déjà le symbole (feuille +
/// "e" + flèche de recyclage), le mot "EcoLindk", et le slogan
/// "COLLECT • VALORISE • IMPACT" — tout est intégré dans une seule image,
/// donc ce widget ne rajoute AUCUN texte par-dessus (ça doublerait le texte).
///
/// COMMENT CHANGER LE LOGO : remplace simplement `assets/images/logo.png`
/// (lockup complet) et/ou `assets/images/logo_icon.png` (symbole seul, sans
/// texte, utilisé quand `iconOnly: true`) par tes propres fichiers. Aucune
/// autre modification de code n'est nécessaire.
class AppLogo extends StatelessWidget {
  /// Largeur d'affichage du logo complet (icône + texte + slogan).
  final double width;

  /// Si `true`, affiche uniquement le symbole (sans le mot "EcoLindk" ni le
  /// slogan) — utile pour les petits espaces (ex. avatar, barre d'app).
  final bool iconOnly;

  const AppLogo({super.key, this.width = 180, this.iconOnly = false});

  @override
  Widget build(BuildContext context) {
    final asset = iconOnly ? 'assets/images/logo_icon.png' : 'assets/images/logo.png';
    return Image.asset(
      asset,
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() {
    // Affiché uniquement si assets/images/logo.png est introuvable.
    return Container(
      width: width * 0.4,
      height: width * 0.4,
      decoration: const BoxDecoration(
        gradient: AppColors.logoGradient,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.eco, color: Colors.white, size: width * 0.22),
    );
  }
}
