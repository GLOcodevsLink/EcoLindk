import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/env_config.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Charge `.env` (clés d'API — ex. GEMINI_API_KEY, voir core/env_config.dart)
  // avant tout le reste : rien n'y accède avant que l'app ne tourne.
  await EnvConfig.loadEnv();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Restaure le mode sombre choisi lors d'une session précédente (onboarding
  // ou profil), puis persiste tout changement ultérieur — quel que soit
  // l'écran qui écrit dans appThemeMode, voir core/theme.dart.
  final settings = SettingsService();
  final savedDarkMode = await settings.loadDarkMode();
  if (savedDarkMode != null) {
    appThemeMode.value = savedDarkMode ? ThemeMode.dark : ThemeMode.light;
  }
  appThemeMode.addListener(() {
    settings.saveDarkMode(appThemeMode.value == ThemeMode.dark);
  });

  runApp(const EcoLindkApp());
}

class EcoLindkApp extends StatelessWidget {
  const EcoLindkApp({super.key});

  @override
  Widget build(BuildContext context) {
    // appThemeMode pilote à la fois le ThemeData Material (theme/darkTheme)
    // ci-dessous et les couleurs dynamiques d'AppColors lues par les écrans
    // (voir core/theme.dart) : changer sa valeur bascule toute l'app entre
    // mode clair et mode sombre.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'EcoLindk',
          debugShowCheckedModeBanner: false,
          theme: ecoLindkTheme,
          darkTheme: ecoLindkDarkTheme,
          themeMode: mode,
          // Tous les libellés de l'app sont volontairement agrandis (demande
          // explicite) — plutôt que de retoucher chaque `fontSize` un par
          // un, un facteur d'échelle global s'applique à tout le texte,
          // combiné au réglage d'accessibilité du téléphone (jamais ignoré)
          // et plafonné pour qu'un système déjà réglé "très grand" ne fasse
          // pas déborder les éléments à hauteur fixe (boutons, badges…).
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final boosted = (mq.textScaler.scale(1.0) * 1.14).clamp(1.0, 1.5);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(boosted)),
              child: child!,
            );
          },
          // Point d'entrée : AuthGate redirige directement au dashboard si une
          // session Firebase est déjà active, sinon affiche l'onboarding.
          // Flow complet (non connecté) : Onboarding -> Landing ->
          // Register (choix de l'acteur, sur cette même page) -> Login
          home: const AuthGate(),
        );
      },
    );
  }
}
