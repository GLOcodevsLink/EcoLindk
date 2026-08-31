import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/language_switcher.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import 'login_screen.dart';

/// Landing Page : premier écran vu par un utilisateur qui n'est pas connecté.
///
/// Reproduit fidèlement le prototype fourni : l'illustration (ciel + décor +
/// scène de collecte) sert de FOND PLEIN à toute la page — pas une vignette
/// séparée. Le sélecteur de langue, le logo, le titre et la description sont
/// superposés directement sur ce fond. Seule la zone du bouton "Commencer",
/// tout en bas, repose sur une carte blanche à coins arrondis.
///
/// Structure (de bas en haut dans le code, de haut en bas à l'écran) :
/// - assets/images/landing_hero.png  : LA photo fournie (ciel, nuages,
///   arbres, immeubles, scène de collecte) sert de fond plein en continu,
///   en BoxFit.cover — ce n'est jamais un ciel reconstruit séparément.
/// - Contenu superposé : IMPACT + sélecteur de langue, logo, titre bicolore,
///   description — tous alignés à gauche (sauf le sélecteur, à droite),
///   avec un léger voile blanc dégradé derrière pour rester lisibles.
/// - Carte blanche uniquement pour le bouton "Commencer", en bas de l'écran.
///
/// "Commencer" mène à LoginScreen ; c'est depuis cet écran que l'utilisateur
/// peut ensuite rejoindre l'inscription s'il n'a pas encore de compte.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final s = AppStrings.of(lang);
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ---- Fond plein : LA photo, désormais étendue avec un
                    // vrai ciel + nuages en haut (pas de zoom artificiel,
                    // pas de voile lourd nécessaire — le fondu vient de
                    // l'image elle-même, comme sur le premier fichier).
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/landing_hero.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    // ---- Voile TRÈS léger, juste pour garantir un contraste
                    // suffisant sur le logo/titre — la majorité de la
                    // lisibilité vient déjà du ciel réel étendu.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 480,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.35),
                              Colors.white.withOpacity(0.20),
                              Colors.white.withOpacity(0.0),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // ---- Contenu superposé (logo, titre, description) ----
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.topRight,
                              child: LanguageSwitcher(iconColor: AppColors.greenDark),
                            ),
                            const SizedBox(height: 2),
                            Center(
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 190,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 68,
                                  height: 68,
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.logoGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.eco, color: Colors.white, size: 34),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: s.landingTaglineLine1,
                                    style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                      height: 1.3,
                                    ),
                                  ),
                                  const TextSpan(text: "\n"),
                                  TextSpan(
                                    text: s.landingTaglineLine2,
                                    style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.greenMid,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.landingDescription,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.navy, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ---- Carte blanche : bouton "Commencer" ----
              // Une poignée (comme un bottom sheet) + une courte phrase
              // d'accroche comblent l'espace au-dessus du bouton : moins de
              // vide, et la carte se lit comme un bloc pensé plutôt qu'un
              // simple padding oublié.
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        s.landingCtaHint,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.greenDark),
                      ),
                      const SizedBox(height: 14),
                      GradientPillButton(
                        label: s.onboardingStart,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                      ),
                    ],
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
