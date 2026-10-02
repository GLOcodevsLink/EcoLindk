import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../firebase_options.dart';
import '../services/settings_service.dart';
import 'admin_app.dart';

/// Point d'entrée du tableau de bord administrateur (Flutter Web), distinct
/// de lib/main.dart — l'app mobile n'en importe rien :
///   flutter run -d chrome -t lib/admin/main_admin.dart
///   flutter build web -t lib/admin/main_admin.dart -o build/admin_web
/// Même projet Firebase (firebase_options.dart) ; accès réservé aux comptes
/// présents dans `admins/{uid}` (voir firestore.rules).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Même préférence clair/sombre que l'app (SettingsService).
  final settings = SettingsService();
  final savedDarkMode = await settings.loadDarkMode();
  if (savedDarkMode != null) {
    appThemeMode.value = savedDarkMode ? ThemeMode.dark : ThemeMode.light;
  }
  appThemeMode.addListener(() {
    settings.saveDarkMode(appThemeMode.value == ThemeMode.dark);
  });

  runApp(const EcoLindkAdminApp());
}
