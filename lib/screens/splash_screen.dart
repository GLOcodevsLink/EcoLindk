import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/decorative_leaves.dart';

/// Écran de démarrage affiché pendant qu'on restaure (ou non) la session
/// Firebase de l'utilisateur — voir [AuthGate]. Le logo `assets/images/logo.png`
/// contient déjà le slogan "COLLECT • VALORISE • IMPACT", donc [AppLogo]
/// suffit à afficher les deux.
///
/// Animation : le logo apparaît en fondu + léger zoom (entrée), puis respire
/// doucement en boucle (léger pulse) pendant que le chargement continue ;
/// l'indicateur de chargement apparaît en fondu une fois l'entrée terminée.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..forward();

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _introController,
    curve: Curves.easeOut,
  );

  late final Animation<double> _introScale = CurvedAnimation(
    parent: _introController,
    curve: Curves.easeOutBack,
  ).drive(Tween(begin: 0.82, end: 1.0));

  late final Animation<double> _pulseScale = CurvedAnimation(
    parent: _pulseController,
    curve: Curves.easeInOut,
  ).drive(Tween(begin: 1.0, end: 1.05));

  @override
  void initState() {
    super.initState();
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const DecorativeLeaves(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation:
                      Listenable.merge([_introController, _pulseController]),
                  builder: (context, child) {
                    final scale = _introScale.value *
                        (_pulseController.isAnimating
                            ? _pulseScale.value
                            : 1.0);
                    return Opacity(
                      opacity: _fade.value,
                      child: Transform.scale(scale: scale, child: child),
                    );
                  },
                  child: const AppLogo(width: 220),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _fade,
                  child: const CircularProgressIndicator(
                    color: AppColors.greenMid,
                    strokeWidth: 2.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
