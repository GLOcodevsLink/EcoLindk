import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AutofillHints, TextInput;
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/phone_field.dart';
import '../widgets/language_switcher.dart';
import '../widgets/app_logo.dart';
import '../widgets/decorative_leaves.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import '../models/user_role.dart';
import 'register_screen.dart';
import 'home_screen.dart';

/// Connexion en une étape : Email+mot de passe OU Téléphone+mot de passe
/// (l'onglet Téléphone retrouve l'email associé via
/// AuthService.findEmailForPhone puisque Firebase Auth n'a pas de "mot de
/// passe + téléphone"). Pas de second facteur (2FA) — voir AuthService pour
/// le pourquoi.
///
/// L'identifiant utilisé (email ou téléphone, jamais le mot de passe) est
/// retenu localement (voir SettingsService) : le numéro de téléphone est
/// pré-rempli à la prochaine ouverture, mais l'email ne l'est PAS — il est
/// seulement proposé en suggestions au fur et à mesure que l'utilisateur
/// tape (RawAutocomplete), jamais rempli automatiquement.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _settings = SettingsService();

  bool _obscure = true;
  bool _useEmail = true; // onglet actif : Email ou Téléphone
  bool _isLoading = false;

  String _fullPhoneNumber = '';
  String? _initialPhoneNumber; // numéro retenu, passé à PhoneField
  List<String> _recentEmails = const []; // suggestions au fur et à mesure de la saisie

  @override
  void initState() {
    super.initState();
    _loadRememberedLogin();
  }

  /// Charge l'historique d'emails (pour les suggestions au clavier, voir
  /// [_emailField]) et, si la dernière connexion était par téléphone,
  /// pré-remplit ce numéro et présélectionne l'onglet Téléphone. L'email, lui,
  /// n'est jamais rempli automatiquement — voir SettingsService.
  Future<void> _loadRememberedLogin() async {
    final recentEmails = await _settings.loadRecentEmails();
    if (mounted) setState(() => _recentEmails = recentEmails);

    final method = await _settings.loadLastLoginMethod();
    if (!mounted || method != 'phone') return;
    final phone = await _settings.loadLastPhone();
    if (!mounted || phone == null || phone.isEmpty) return;
    setState(() {
      _useEmail = false;
      _fullPhoneNumber = phone;
      _initialPhoneNumber = phone;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit(AppStrings s) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String email;
      if (_useEmail) {
        email = _emailController.text.trim();
      } else {
        final found = await _authService.findEmailForPhone(_fullPhoneNumber);
        if (found == null) {
          _showSnack(s.noAccountForPhone);
          setState(() => _isLoading = false);
          return;
        }
        email = found;
      }

      await _authService.signIn(
          email: email, password: _passwordController.text);
      if (!mounted) return;

      if (_useEmail) {
        await _settings.rememberEmailLogin(email);
      } else {
        await _settings.rememberPhoneLogin(_fullPhoneNumber);
      }

      _finishLogin();
    } on FirebaseAuthException catch (e) {
      _showSnack(s.authError(e.code));
    } catch (_) {
      _showSnack(s.authError('unknown'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Demande l'email (pré-rempli si l'onglet Email est actif, ou retrouvé
  /// via [AuthService.findEmailForPhone] si l'onglet Téléphone est actif et
  /// qu'un numéro a déjà été saisi), puis envoie le lien de réinitialisation
  /// standard de Firebase Auth.
  Future<void> _forgotPassword(AppStrings s) async {
    final controller = TextEditingController(
        text: _useEmail ? _emailController.text.trim() : '');
    if (!_useEmail && _fullPhoneNumber.isNotEmpty) {
      final found = await _authService.findEmailForPhone(_fullPhoneNumber);
      if (found != null) controller.text = found;
    }
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.forgotPassword),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(
              hintText: s.resetPasswordEmailHint,
              prefixIcon: const Icon(Icons.email_outlined, size: 19),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? s.requiredField : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: Text(s.sendResetLink,
                style: const TextStyle(
                    color: AppColors.greenMid, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;

    try {
      await _authService.sendPasswordResetEmail(email);
      _showSnack(s.resetLinkSent);
    } on FirebaseAuthException catch (e) {
      _showSnack(s.authError(e.code));
    } catch (_) {
      _showSnack(s.authError('unknown'));
    }
  }

  void _finishLogin() {
    if (!mounted) return;
    TextInput.finishAutofillContext();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  /// Google/Apple : logos affichés à titre de perspective seulement, pas
  /// encore fonctionnels (choix explicite — voir AuthService.signInWithGoogle
  /// / signInWithApple, déjà prêts pour le jour où on les active vraiment).
  void _socialComingSoon(AppLanguage lang) {
    _showSnack(lang == AppLanguage.fr
        ? "Bientôt disponible."
        : "Coming soon.");
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
              body: Stack(
                children: [
                  const DecorativeLeaves(subtle: true),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _credentialsView(s, lang),
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

  Widget _credentialsView(AppStrings s, AppLanguage lang) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: ListView(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: LanguageSwitcher(iconColor: AppColors.heading),
            ),
            const SizedBox(height: 4),
            const Center(child: AppLogo(width: 170)),
            const SizedBox(height: 20),
            Text(s.loginTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText)),
            const SizedBox(height: 4),
            Text(s.loginSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textGray)),
            const SizedBox(height: 22),

            // Onglets Email / Téléphone
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _tab(s.emailTab, _useEmail,
                          () => setState(() => _useEmail = true))),
                  Expanded(
                      child: _tab(s.phoneTab, !_useEmail,
                          () => setState(() => _useEmail = false))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_useEmail)
              _emailField(s, lang)
            else
              PhoneField(
                controller: _phoneController,
                initialValue: _initialPhoneNumber,
                onChanged: (full) => _fullPhoneNumber = full,
              ),

            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(s),
              decoration: InputDecoration(
                hintText: lang == AppLanguage.fr
                    ? "Votre mot de passe"
                    : "Your password",
                prefixIcon: const Icon(Icons.lock_outline, size: 19),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? s.requiredField : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _forgotPassword(s),
                child: Text(s.forgotPassword,
                    style: TextStyle(
                        color: AppColors.greenMid,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ),
            ),
            const SizedBox(height: 6),
            _isLoading
                ? const SizedBox(
                    height: 52,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.greenMid,
                        strokeWidth: 2.4,
                      ),
                    ),
                  )
                : GradientPillButton(
                    label: s.logIn, onPressed: () => _submit(s)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Divider(color: AppColors.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(s.continueWith,
                    style:
                        TextStyle(fontSize: 11.5, color: AppColors.textGray)),
              ),
              Expanded(child: Divider(color: AppColors.line)),
            ]),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _socialIconButton(
                    onTap: () => _socialComingSoon(lang),
                    child: Image.asset(
                      'assets/images/google_logo.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'G',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4285F4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _socialIconButton(
                    onTap: () => _socialComingSoon(lang),
                    child: const Icon(Icons.apple, size: 24, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Center(
              child: Text(s.newToApp,
                  style: TextStyle(fontSize: 13, color: AppColors.textGray)),
            ),
            const SizedBox(height: 6),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _signUpLink(s.signUpAsHousehold,
                      () => _goToRegister(UserRole.household)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(s.or.toLowerCase(),
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textGray)),
                  ),
                  _signUpLink(s.signUpAsCollector,
                      () => _goToRegister(UserRole.collector)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Champ email : ne se pré-remplit jamais tout seul. Dès que l'utilisateur
  /// tape, propose en dessous les adresses déjà utilisées sur cet appareil
  /// qui correspondent à ce qui est tapé (voir [_recentEmails] /
  /// SettingsService.loadRecentEmails) — comme une suggestion de clavier, pas
  /// un remplissage automatique. `textEditingController`/`focusNode` sont les
  /// nôtres (pas ceux, internes, que RawAutocomplete créerait sinon) pour que
  /// `_emailController` reste la source de vérité utilisée par [_submit].
  Widget _emailField(AppStrings s, AppLanguage lang) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: _emailController,
          focusNode: _emailFocusNode,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return const Iterable<String>.empty();
            return _recentEmails
                .where((e) => e.toLowerCase().contains(query));
          },
          onSelected: (selection) => _emailController.text = selection,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username
              ],
              decoration: InputDecoration(
                hintText: lang == AppLanguage.fr
                    ? "Entrez votre email"
                    : "Enter your email",
                prefixIcon: const Icon(Icons.email_outlined, size: 19),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? s.requiredField : null,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: AppColors.card,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.history,
                              size: 17, color: AppColors.textGray),
                          title: Text(option, style: const TextStyle(fontSize: 13)),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: active ? AppColors.buttonGradient : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textGray,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// Bouton de connexion sociale réduit au logo (pas de texte "Google"/"Apple"
  /// à côté) — juste le symbole, dans un cercle bordé.
  Widget _socialIconButton({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: _isLoading ? null : onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line, width: 1.4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(child: child),
      ),
    );
  }

  /// Ouvre l'inscription avec [role] déjà choisi (voir RegisterScreen.presetRole)
  /// — l'utilisateur n'a plus à re-choisir son rôle après la création du compte.
  void _goToRegister(UserRole role) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RegisterScreen(presetRole: role)),
    );
  }

  Widget _signUpLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              color: AppColors.greenMid,
              fontWeight: FontWeight.w800)),
    );
  }
}
