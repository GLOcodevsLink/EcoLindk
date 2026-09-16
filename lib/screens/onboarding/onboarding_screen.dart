import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/settings_service.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/language_switcher.dart';
import 'onboarding_animations.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/strings.dart';
import '../landing_screen.dart';

/// Écran d'accueil au tout premier lancement de l'app (une seule fois).
/// 5 slides : les 4 premiers ont une illustration ANIMÉE en plusieurs étapes
/// (voir onboarding_animations.dart) ; le 5e reprend l'écran de réglages
/// rapides (notifications / mode sombre).
///
/// Fond SOMBRE sur tout l'onboarding (demande explicite) — texte et
/// éléments d'interface adaptés en conséquence (blanc/gris clair au lieu
/// de vert foncé sur fond clair).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _index = 0;
  static const int _slideCount = 5;

  // Durées par slide : la première (localisation) est volontairement plus
  // lente pour laisser le temps de bien suivre carte -> camion -> pin.
  static const List<int> _animDurationsMs = [3400, 2900, 2900, 2900];
  late final List<AnimationController> _animControllers = List.generate(
    4, // seules les 4 premières slides ont une illustration animée
    (i) => AnimationController(
        vsync: this, duration: Duration(milliseconds: _animDurationsMs[i])),
  );

  final _settings = SettingsService();

  bool _notifications = true;
  bool _settingsBusy = false;

  @override
  void initState() {
    super.initState();
    _animControllers[0].forward();
    _loadSettings();
  }

  /// Réconcilie le réglage persisté avec l'état réel du système (ex:
  /// notifications refusées manuellement dans les réglages OS depuis la
  /// dernière ouverture) pour que l'interrupteur ne mente jamais.
  Future<void> _loadSettings() async {
    final savedNotifications = await _settings.loadNotifications();
    final osNotificationsGranted = await Permission.notification.isGranted;
    if (!mounted) return;
    setState(() {
      _notifications = savedNotifications && osNotificationsGranted;
    });
  }

  Future<void> _onNotificationsChanged(bool value) async {
    setState(() => _settingsBusy = true);
    var granted = false;
    if (value) {
      final status = await Permission.notification.request();
      granted = status.isGranted;
      if (!granted && mounted) {
        _showSettingsSnack(status.isPermanentlyDenied
            ? (appLanguage.value == AppLanguage.fr
                ? "Autorisez les notifications dans les réglages du système."
                : "Enable notifications from your system settings.")
            : (appLanguage.value == AppLanguage.fr
                ? "Autorisation refusée."
                : "Permission denied."));
      }
    }
    await _settings.saveNotifications(granted);
    if (!mounted) return;
    setState(() {
      _notifications = granted;
      _settingsBusy = false;
    });
  }

  void _showSettingsSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    for (final c in _animControllers) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    if (i < _animControllers.length) {
      _animControllers[i].forward(from: 0);
    }
  }

  void _next() {
    if (_index < _slideCount - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else {
      _goToLanding();
    }
  }

  void _goToLanding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
    );
  }

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
              backgroundColor: AppColors.darkBackground,
              body: SafeArea(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: LanguageSwitcher(iconColor: Colors.white70),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 20, top: 8),
                          child: TextButton(
                            onPressed: _goToLanding,
                            child: Text(s.onboardingSkip,
                                style: const TextStyle(
                                    color: AppColors.greenBright,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        children: [
                          _animatedSlide(
                            illustration: AnimatedLocationIllustration(
                                t: _animControllers[0]),
                            title: s.slide1Title,
                            subtitle: s.slide1Subtitle,
                            trailing: _materialsStrip(lang),
                          ),
                          _animatedSlide(
                            illustration: AnimatedWeighIllustration(
                                t: _animControllers[1]),
                            title: s.slide2Title,
                            subtitle: s.slide2Subtitle,
                          ),
                          _animatedSlide(
                            illustration: AnimatedWalletIllustration(
                                t: _animControllers[2]),
                            title: s.slide3Title,
                            subtitle: s.slide3Subtitle,
                          ),
                          _animatedSlide(
                            illustration: AnimatedFundsIllustration(
                                t: _animControllers[3]),
                            title: s.slide4Title,
                            subtitle: s.slide4Subtitle,
                          ),
                          _settingsSlide(s),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slideCount, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color:
                                active ? AppColors.greenBright : Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
                      child: GradientPillButton(
                        label: _index == _slideCount - 1
                            ? s.onboardingStart
                            : s.onboardingNext,
                        onPressed: _next,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _animatedSlide({
    required Widget illustration,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          illustration,
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13.5, color: Colors.white60, height: 1.6),
          ),
          if (trailing != null) ...[const SizedBox(height: 18), trailing],
        ],
      ),
    );
  }

  /// Bande de matériaux recyclables — plastique, canettes, carton, métal,
  /// verre — affichée sous le titre/sous-titre de la slide "Recyclez à
  /// votre façon" (celle qui correspond le mieux au recyclage en général
  /// parmi les 4 slides animées).
  Widget _materialsStrip(AppLanguage lang) {
    final fr = lang == AppLanguage.fr;
    final materials = <(IconData, String)>[
      (Icons.local_drink_outlined, fr ? "Plastique" : "Plastic"),
      (Icons.sports_bar_outlined, fr ? "Canettes" : "Beverage cans"),
      (Icons.inventory_2_outlined, fr ? "Carton" : "Carton"),
      (Icons.settings_input_component_outlined, fr ? "Métaux" : "Metals"),
      (Icons.wine_bar_outlined, fr ? "Verre" : "Glass"),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: materials
          .map((m) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.greenBright.withOpacity(0.5)),
                    ),
                    child: Icon(m.$1, color: AppColors.greenBright, size: 19),
                  ),
                  const SizedBox(height: 4),
                  Text(m.$2, style: const TextStyle(color: Colors.white60, fontSize: 9.5)),
                ],
              ))
          .toList(),
    );
  }

  Widget _settingsSlide(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
                gradient: AppColors.logoGradient, shape: BoxShape.circle),
            child: const Icon(Icons.tune, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 20),
          Text(
            s.slide5Title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            s.slide5Subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12.5, color: Colors.white60, height: 1.5),
          ),
          const SizedBox(height: 22),
          _settingsToggle(
              icon: Icons.notifications_outlined,
              label: s.settingNotifications,
              value: _notifications,
              onChanged: _settingsBusy ? null : _onNotificationsChanged),
          _settingsToggle(
              icon: Icons.dark_mode_outlined,
              label: s.settingDarkMode,
              value: isDarkMode,
              onChanged: (v) =>
                  appThemeMode.value = v ? ThemeMode.dark : ThemeMode.light),
          const SizedBox(height: 12),
          Text(s.settingsNote,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _settingsToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.greenBright, size: 19),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5))),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.greenBright),
        ],
      ),
    );
  }
}
