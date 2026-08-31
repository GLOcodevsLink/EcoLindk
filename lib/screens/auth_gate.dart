import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'splash_screen.dart';

/// Point d'entrée réel de l'app (voir main.dart).
///
/// Firebase persiste la session de connexion sur l'appareil : on affiche le
/// [SplashScreen] (logo + slogan) pendant la restauration de cette session,
/// puis on redirige directement au dashboard si elle est active, sinon vers
/// l'onboarding. Le splash reste visible au moins [_minSplashDuration], pour
/// éviter un flash trop bref même quand Firebase répond instantanément.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _minSplashDuration = Duration(milliseconds: 1100);

  bool _ready = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      FirebaseAuth.instance.authStateChanges().first,
      Future.delayed(_minSplashDuration),
    ]);
    if (!mounted) return;
    setState(() {
      _user = results[0] as User?;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashScreen();
    return _user != null ? const HomeScreen() : const OnboardingScreen();
  }
}
