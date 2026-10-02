import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/decorative_leaves.dart';
import '../widgets/gradient_pill_button.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Vérification de l'adresse email — vraie, via le lien envoyé par Firebase
/// Auth (voir AuthService.sendEmailVerification). Affichée pendant
/// l'inscription (voir RegisterScreen) puis à chaque ouverture de l'app
/// tant que le lien n'a pas été cliqué (voir HomeScreen) — uniquement pour
/// les comptes créés avec cette vérification, jamais pour les anciens.
/// Tant que le lien n'a pas été ouvert, on ne peut que renvoyer l'email,
/// revenir en arrière, se déconnecter ou recommencer l'inscription — jamais
/// entrer dans l'app.
/// L'état est revérifié toutes les quelques secondes : l'utilisateur n'a
/// qu'à revenir dans l'app après avoir cliqué sur le lien.
class EmailVerificationScreen extends StatefulWidget {
  /// Appelé une fois l'email vérifié, avec le contexte de cet écran (pour
  /// naviguer vers la suite).
  final void Function(BuildContext context) onVerified;
  const EmailVerificationScreen({super.key, required this.onVerified});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  static const _pollEvery = Duration(seconds: 3);
  static const _resendCooldown = Duration(seconds: 60);

  final _authService = AuthService();
  Timer? _poll;
  Timer? _cooldownTicker;
  DateTime? _lastSentAt;
  bool _checking = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // L'email vient d'être envoyé à l'inscription : même délai avant de
    // pouvoir le redemander.
    _lastSentAt = DateTime.now();
    _poll = Timer.periodic(_pollEvery, (_) => _check());
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _resendWait > Duration.zero) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _cooldownTicker?.cancel();
    super.dispose();
  }

  /// Retour dans l'app (typiquement après avoir cliqué sur le lien depuis
  /// la boîte mail) : on revérifie tout de suite.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  bool get _fr => appLanguage.value == AppLanguage.fr;

  Duration get _resendWait {
    final sent = _lastSentAt;
    if (sent == null) return Duration.zero;
    final left = _resendCooldown - DateTime.now().difference(sent);
    return left.isNegative ? Duration.zero : left;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Vérification automatique : relit l'état du compte toutes les
  /// [_pollEvery] et au retour dans l'app. Dès que le lien a été ouvert,
  /// l'inscription continue d'elle-même — aucun bouton à toucher. Une erreur
  /// passagère (réseau) est simplement réessayée au tour suivant.
  Future<void> _check() async {
    if (_checking || _done) return;
    _checking = true;
    try {
      final verified = await _authService.reloadEmailVerified();
      if (!mounted || !verified) return;
      _poll?.cancel();
      setState(() => _done = true);
      // Laisse voir la coche de confirmation un court instant.
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) widget.onVerified(context);
    } catch (_) {
      // Réessayé automatiquement au prochain tour.
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    try {
      await _authService.sendEmailVerification(french: _fr);
      setState(() => _lastSentAt = DateTime.now());
      _showSnack(_fr ? "Email de vérification renvoyé." : "Verification email sent again.");
    } on FirebaseAuthException catch (e) {
      _showSnack(AppStrings.of(appLanguage.value).authError(e.code));
    } catch (_) {
      _showSnack(AppStrings.of(appLanguage.value).authError('unknown'));
    }
  }

  /// "Mauvaise adresse ?" : annule l'inscription (compte, fiche et entrée
  /// téléphone supprimés) et revient au formulaire, déjà rempli, pour
  /// corriger l'email et recommencer.
  Future<void> _restart() async {
    final fr = _fr;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(fr ? "Recommencer l'inscription ?" : "Restart sign-up?"),
        content: Text(fr
            ? "Le compte en cours de création sera supprimé. Vous pourrez corriger votre adresse email."
            : "The account being created will be deleted. You'll be able to fix your email address."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(fr ? "Annuler" : "Cancel")),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(fr ? "Recommencer" : "Restart",
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    _poll?.cancel();
    _done = true;
    await _authService.abandonRegistration();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(false); // retour au formulaire d'inscription, déjà rempli
    } else {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
        (route) => false,
      );
    }
  }

  /// Quitte sans supprimer le compte : l'utilisateur pourra revenir plus
  /// tard, cliquer sur le lien et se connecter.
  Future<void> _signOut() async {
    _poll?.cancel();
    _done = true;
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Retour (flèche ou bouton du système) sans avoir cliqué sur le lien :
  /// l'utilisateur est déconnecté — le compte est conservé — puis revient à
  /// l'écran précédent (formulaire d'inscription, déjà rempli) ou, s'il n'y
  /// en a pas (écran affiché à l'ouverture de l'app), à la connexion. Il ne
  /// peut donc pas accéder à l'app : à sa prochaine connexion, cet écran
  /// réapparaîtra tant que le lien n'aura pas été ouvert.
  Future<void> _goBack() async {
    if (_done) return;
    _poll?.cancel();
    _done = true;
    await _authService.signOut();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(false);
    } else {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        final email = _authService.currentUser?.email ?? '';
        final wait = _resendWait;
        return PopScope(
          canPop: false,
          // Bouton retour du système : même sortie que la flèche.
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _goBack();
          },
          child: Scaffold(
            body: Stack(
              children: [
                const DecorativeLeaves(subtle: true),
                SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: _done ? null : _goBack,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          tooltip: fr ? "Retour" : "Back",
                          icon: Icon(Icons.arrow_back, color: AppColors.heading),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                              gradient: AppColors.logoGradient, shape: BoxShape.circle),
                          child: const Icon(Icons.mark_email_unread_outlined,
                              color: Colors.white, size: 40),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(fr ? "Vérifiez votre email" : "Verify your email",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mainText)),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 13.5, color: AppColors.textGray, height: 1.45),
                          children: [
                            TextSpan(text: fr ? "Nous avons envoyé un lien de confirmation à " : "We sent a confirmation link to "),
                            TextSpan(
                                text: email,
                                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.mainText)),
                            TextSpan(
                                text: fr
                                    ? ". Ouvrez-le : l'inscription continuera automatiquement."
                                    : ". Open it: sign-up will continue automatically."),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                          fr
                              ? "Pensez à regarder dans vos spams."
                              : "Remember to check your spam folder.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                      const SizedBox(height: 32),
                      _WaitingIndicator(done: _done, fr: fr),
                      const SizedBox(height: 12),
                      GradientPillButton(
                        label: wait == Duration.zero
                            ? (fr ? "Renvoyer l'email" : "Resend email")
                            : (fr
                                ? "Renvoyer l'email (${wait.inSeconds + 1} s)"
                                : "Resend email (${wait.inSeconds + 1}s)"),
                        onPressed: wait == Duration.zero ? _resend : () {},
                        outlined: true,
                        trailingIcon: Icons.refresh,
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton(
                          onPressed: _signOut,
                          child: Text(fr ? "Se déconnecter" : "Sign out",
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textGray)),
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: _restart,
                          child: Text(
                              fr
                                  ? "Mauvaise adresse ? Recommencer l'inscription"
                                  : "Wrong address? Restart sign-up",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, color: AppColors.textGray)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Attente du clic sur le lien : petit indicateur animé, remplacé par une
/// coche verte dès que l'email est vérifié.
class _WaitingIndicator extends StatelessWidget {
  final bool done;
  final bool fr;
  const _WaitingIndicator({required this.done, required this.fr});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(done),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: done ? AppColors.greenMid.withValues(alpha: 0.12) : AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (done)
              const Icon(Icons.check_circle_rounded, color: AppColors.greenDeep, size: 22)
            else
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.2),
              ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                done
                    ? (fr ? "Email vérifié !" : "Email verified!")
                    : (fr ? "En attente de votre clic sur le lien…" : "Waiting for you to open the link…"),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: done ? AppColors.greenDeep : AppColors.textGray),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
