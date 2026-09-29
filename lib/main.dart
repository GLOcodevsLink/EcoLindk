import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/ai_model_settings.dart';
import 'services/settings_service.dart';

/// App Check : prouve à Firebase que les appels (IA, Firestore) viennent de
/// l'app EcoLindk authentique. Désactivé par défaut, car tant qu'il n'est
/// pas configuré dans la console Firebase, les appels à l'IA échoueraient.
/// Une fois configuré (voir FIREBASE_SANS_SERVEUR.md), lancer l'app avec
/// `--dart-define=ENABLE_APP_CHECK=true`.
const _enableAppCheck = bool.fromEnvironment('ENABLE_APP_CHECK');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_enableAppCheck) {
    try {
      await FirebaseAppCheck.instance.activate(
        // En debug : jeton de débogage à enregistrer dans la console ; en
        // release : Play Integrity (app installée depuis le Play Store).
        providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
      );
    } catch (e) {
      debugPrint('App Check non activé : $e');
    }
  }

  // Modèles d'IA réglables à distance (Remote Config) — sans attendre :
  // les valeurs par défaut suffisent au premier lancement.
  AiModelSettings.init();

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
