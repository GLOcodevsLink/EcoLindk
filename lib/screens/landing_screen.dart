import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/language_switcher.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import 'register_screen.dart';

/// Landing Page : premier écran vu par un utilisateur qui n'est pas connecté.
///
/// Reproduit fidèlement le prototype fourni : l'illustration (ciel + décor +
/// scène de collecte) sert de FOND PLEIN à toute la page — pas une vignette
/// séparée (demande explicite : "l'image doit toujours être là", après un
/// détour où elle avait été isolée dans sa propre carte séparée du texte).
/// Le sélecteur de langue, le logo, le titre et la description sont
/// superposés directement sur ce fond, poussés vers le haut (demande
/// explicite : "repousse les textes un peu plus haut pour éviter que ça ne
/// touche les cheveux de la fille") pour rester dans la zone de ciel, avant
/// que la photo n'entre dans le vif du décor. Seule la zone du bouton
/// "Commencer", tout en bas, repose sur une carte blanche à coins arrondis.
///
/// Pas de bouton "Demandez à notre assistant IA" ici (demande explicite :
/// il tombait sur le visage de la fille de la photo) — l'assistant reste
/// accessible depuis les dashboards une fois connecté.
///
/// "Commencer" mène à RegisterScreen, qui commence par demander le rôle
/// (Fournisseur de déchets / Collecteur) sur cette même page — c'est depuis
/// cet écran que l'utilisateur peut ensuite rejoindre la connexion s'il a
/// déjà un compte (lien "Se connecter" en bas de RegisterScreen).
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: appLanguage,
          builder: (context, lang, _) {
            final s = AppStrings.of(lang);
            return Scaffold(
              backgroundColor: AppColors.surface,
              body: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ---- Fond plein : LA photo, en continu, jamais isolée
                        // dans une vignette séparée (demande explicite).
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
                          height: 420,
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
                        // ---- Contenu superposé (logo, titre, description) —
                        // resserré et poussé vers le haut (demande explicite)
                        // pour rester dans le ciel, sans toucher les cheveux
                        // de la fille plus bas dans la photo.
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: Alignment.topRight,
                                  child: LanguageSwitcher(
                                      iconColor: AppColors.heading),
                                ),
                                Center(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 160,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      width: 58,
                                      height: 58,
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.logoGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.eco,
                                          color: Colors.white, size: 30),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: s.landingTaglineLine1,
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.navy,
                                          height: 1.25,
                                        ),
                                      ),
                                      const TextSpan(text: "\n"),
                                      TextSpan(
                                        text: s.landingTaglineLine2,
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.greenMid,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.landingDescription,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.navy,
                                      height: 1.4),
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
                    decoration: BoxDecoration(
                      // Blanc doux (comme le reste de l'app, voir
                      // AppColors.card) — redevenu clair : la version verte
                      // plus soutenue tranchait trop nettement sur la photo
                      // juste au-dessus ("une ligne qui barre l'image").
                      color: AppColors.card,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
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
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mainText),
                          ),
                          const SizedBox(height: 14),
                          GradientPillButton(
                            label: s.onboardingStart,
                            gradient: AppColors.landingStartButtonGradient,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen()),
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
      },
    );
  }
}
