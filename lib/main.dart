import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EcoLindkApp());
}

class EcoLindkApp extends StatelessWidget {
  const EcoLindkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoLindk',
      debugShowCheckedModeBanner: false,
      theme: ecoLindkTheme,
      // Point d'entrée : AuthGate redirige directement au dashboard si une
      // session Firebase est déjà active, sinon affiche l'onboarding.
      // Flow complet (non connecté) : Onboarding -> Landing ->
      // Register (choix de l'acteur) -> Login
      home: const AuthGate(),
    );
  }
}
