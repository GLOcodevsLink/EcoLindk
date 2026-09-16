import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show AutofillHints, TextInput;
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/phone_field.dart';
import '../widgets/language_switcher.dart';
import '../widgets/decorative_leaves.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import '../models/user_role.dart';
import 'collector_setup_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Inscription, en 3 étapes une fois le rôle choisi :
/// 0. Choix du rôle — Fournisseur de déchets ou Collecteur, affiché sur
///    cette même page (aucune navigation, voir [_role]/[_roleChoiceView]) via
///    deux grandes cartes. Une fois choisi, ce choix est définitif pour le
///    reste du formulaire : seul un badge rappelle le rôle choisi (voir
///    [_roleBadge]) — plus aucun bouton vers l'autre rôle n'est visible
///    (revenir en arrière depuis l'étape 1 ramène au choix, voir [_goBack]).
/// 1. Identité — prénom, nom, email, mot de passe.
/// 2. Adresse.
/// 3. Téléphone + acceptation des conditions -> création du compte Firebase
///    (email/mot de passe). Aucune vérification par SMS n'est requise : le
///    numéro est simplement enregistré sur le profil.
///
/// [presetRole] : si l'utilisateur est arrivé ici via un lien "S'inscrire
/// comme Ménage/Collecteur" (voir LoginScreen), le rôle est déjà fixé et
/// l'étape de choix (0) est sautée.
class RegisterScreen extends StatefulWidget {
  final UserRole? presetRole;
  const RegisterScreen({super.key, this.presetRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _totalSteps = 3;
  int _step = 0;

  final _identityFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _obscureConfirmPw = true;
  bool _acceptTerms = false;

  final _authService = AuthService();

  String _fullPhoneNumber = '';
  bool _isCreatingAccount = false;

  /// `null` tant que l'utilisateur n'a pas choisi son rôle : dans ce cas
  /// [_roleChoiceView] est affichée à la place du formulaire, sur cette même
  /// page (voir doc de la classe). Initialisé depuis [widget.presetRole].
  UserRole? _role;

  @override
  void initState() {
    super.initState();
    _role = widget.presetRole;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _goNext(AppLanguage lang) {
    if (_step == 0) {
      if (!_identityFormKey.currentState!.validate()) return;
      if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
        _showSnack(lang == AppLanguage.fr
            ? "Les mots de passe ne correspondent pas"
            : "Passwords do not match");
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (!_addressFormKey.currentState!.validate()) return;
      setState(() => _step = 2);
    }
  }

  /// Étape 0 du formulaire -> retour au choix du rôle (même page, voir
  /// [_role]) plutôt que de quitter l'écran, sauf si ce rôle était imposé
  /// dès l'arrivée ([widget.presetRole]) : dans ce cas il n'y a pas de vue
  /// "choix du rôle" à laquelle revenir, donc on quitte l'écran normalement.
  void _goBack() {
    if (_role == null) {
      Navigator.of(context).pop();
      return;
    }
    if (_step == 0) {
      if (widget.presetRole == null) {
        setState(() => _role = null);
      } else {
        Navigator.of(context).pop();
      }
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _createAccount(AppStrings s) async {
    if (!_acceptTerms) {
      _showSnack(s.acceptTerms);
      return;
    }

    setState(() => _isCreatingAccount = true);
    try {
      final credential = await _authService.registerAccount(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        address: _addressCtrl.text,
        phoneNumber: _fullPhoneNumber,
      );

      // Comme sur l'écran de connexion : signale au gestionnaire de mots de
      // passe du système que la saisie est terminée, pour qu'il propose de
      // sauvegarder ces identifiants (et donc de les re-proposer au login).
      TextInput.finishAutofillContext();
      if (!mounted) return;
      await _proceedAfterAccountCreation(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(s.authError(e.code));
    } catch (_) {
      if (!mounted) return;
      _showSnack(s.authError('unknown'));
    } finally {
      if (mounted) setState(() => _isCreatingAccount = false);
    }
  }

  /// Une fois le compte créé : finalise directement avec le rôle choisi en
  /// étape 0 ([_role], toujours non-null ici puisque le formulaire n'est
  /// atteignable qu'après ce choix — voir [_roleChoiceView]).
  Future<void> _proceedAfterAccountCreation(UserCredential credential) async {
    final uid = credential.user!.uid;
    final firstName = _firstNameCtrl.text.trim();

    switch (_role!) {
      case UserRole.household:
        await _authService.completeHouseholdRegistration(uid);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      case UserRole.collector:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                CollectorSetupScreen(uid: uid, firstName: firstName),
          ),
        );
    }
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
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _isCreatingAccount ? null : _goBack,
                                icon: Icon(Icons.arrow_back,
                                    color: AppColors.heading),
                              ),
                              Row(
                                children: [
                                  LanguageSwitcher(),
                                  const SizedBox(width: 8),
                                  Image.asset(
                                    'assets/images/logo_icon.png',
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      width: 38,
                                      height: 38,
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.logoGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.eco,
                                          color: Colors.white, size: 19),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_role != null) ...[
                            _StepIndicator(
                                step: _step,
                                total: _totalSteps,
                                label: s.stepOf(_step + 1, _totalSteps)),
                            const SizedBox(height: 14),
                          ],
                          Text(s.registerTitle,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.mainText)),
                          const SizedBox(height: 4),
                          Text(s.registerSubtitle,
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.textGray)),
                          if (_role != null) ...[
                            const SizedBox(height: 8),
                            _roleBadge(s),
                          ],
                          const SizedBox(height: 18),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _role == null
                                  ? _roleChoiceView(s)
                                  : switch (_step) {
                                      0 => _identityStep(s),
                                      1 => _addressStep(s),
                                      _ => _phoneStep(s),
                                    },
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_role != null)
                            _isCreatingAccount
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: CircularProgressIndicator(
                                        color: AppColors.greenMid,
                                        strokeWidth: 2.4),
                                  )
                                : GradientPillButton(
                                    label:
                                        _step == 2 ? s.createMyAccount : s.next,
                                    onPressed: _step == 2
                                        ? () => _createAccount(s)
                                        : () => _goNext(lang),
                                  ),
                          const SizedBox(height: 18),
                          Center(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textGray),
                                children: [
                                  TextSpan(text: s.alreadyAccount),
                                  TextSpan(
                                    text: s.logIn,
                                    style: TextStyle(
                                        color: AppColors.greenMid,
                                        fontWeight: FontWeight.w800),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () =>
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const LoginScreen()),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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

  /// Étape 0, affichée tant que [_role] est `null` : deux grandes cartes
  /// "Fournisseur de déchets" / "Collecteur". Taper l'une d'elles fixe
  /// [_role] (setState) — pas de Navigator.push, on reste sur cette même
  /// page qui se redessine alors avec le formulaire (voir [build]).
  Widget _roleChoiceView(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.signUpAs,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textGray,
                letterSpacing: 0.6)),
        const SizedBox(height: 12),
        ...UserRole.values.map(
          (role) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _roleChoiceCard(role, s),
          ),
        ),
      ],
    );
  }

  Widget _roleChoiceCard(UserRole role, AppStrings s) {
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.4),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(role.icon, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(role.label(s),
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mainText)),
            ),
            Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }

  /// Affiché une fois [_role] choisi, en haut du formulaire : simple rappel
  /// non interactif du rôle choisi — aucun bouton vers l'autre rôle n'est
  /// visible ici (le choix est définitif ; revenir en arrière depuis
  /// l'étape 1 ramène à [_roleChoiceView] si l'on veut vraiment changer —
  /// voir [_goBack]).
  Widget _roleBadge(AppStrings s) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.greenBright.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_role!.icon, size: 14, color: AppColors.greenDeep),
            const SizedBox(width: 6),
            Text(_role!.label(s),
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.greenDeep)),
          ],
        ),
      ),
    );
  }

  Widget _identityStep(AppStrings s) {
    return Form(
      key: _identityFormKey,
      // Regroupe email + mot de passe pour le gestionnaire de mots de passe
      // du système : après une inscription réussie (voir _createAccount), il
      // peut proposer de les enregistrer, puis les re-proposer au login.
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: _field(
                        _firstNameCtrl, s.firstName, Icons.person_outline, s)),
                const SizedBox(width: 12),
                Expanded(
                    child: _field(
                        _lastNameCtrl, s.lastName, Icons.person_outline, s)),
              ],
            ),
            const SizedBox(height: 14),
            _field(_emailCtrl, s.email, Icons.email_outlined, s,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email]),
            const SizedBox(height: 14),
            _passwordFields(s),
          ],
        ),
      ),
    );
  }

  Widget _addressStep(AppStrings s) {
    return Form(
      key: _addressFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.addressStepTitle,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mainText)),
          const SizedBox(height: 4),
          Text(s.addressStepSubtitle,
              style: TextStyle(fontSize: 12, color: AppColors.textGray)),
          const SizedBox(height: 16),
          _field(_addressCtrl, s.address, Icons.home_outlined, s),
        ],
      ),
    );
  }

  Widget _phoneStep(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.phoneStepTitle,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.mainText)),
        const SizedBox(height: 4),
        Text(s.phoneStepSubtitle,
            style: TextStyle(fontSize: 12, color: AppColors.textGray)),
        const SizedBox(height: 16),
        PhoneField(
          controller: _phoneCtrl,
          onChanged: (full) => _fullPhoneNumber = full,
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _acceptTerms,
                activeColor: AppColors.greenMid,
                onChanged: (v) => setState(() => _acceptTerms = v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.acceptTerms,
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.textGray, height: 1.4)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(
      TextEditingController c, String label, IconData icon, AppStrings s,
      {TextInputType? keyboardType, List<String>? autofillHints}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      decoration:
          InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19)),
      validator: (v) => (v == null || v.isEmpty) ? s.requiredField : null,
    );
  }

  Widget _passwordFields(AppStrings s) {
    return Column(
      children: [
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePw,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: s.passwordLabel,
            prefixIcon: const Icon(Icons.lock_outline, size: 19),
            suffixIcon: IconButton(
              icon: Icon(_obscurePw
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePw = !_obscurePw),
            ),
          ),
          validator: (v) {
            if (v == null || v.length < 8) return s.passwordTooShort;
            if (!RegExp(r'\d').hasMatch(v)) return s.passwordNeedsDigit;
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirmPasswordCtrl,
          obscureText: _obscureConfirmPw,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: s.confirmPassword,
            prefixIcon: const Icon(Icons.lock_outline, size: 19),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPw
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscureConfirmPw = !_obscureConfirmPw),
            ),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? s.confirmationRequired : null,
        ),
      ],
    );
  }
}

/// Petit indicateur de progression (une barre par étape) pour le formulaire.
class _StepIndicator extends StatelessWidget {
  final int step; // 0-based
  final int total;
  final String label;
  const _StepIndicator(
      {required this.step, required this.total, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(total, (i) {
            final active = i <= step;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                height: 4,
                decoration: BoxDecoration(
                  color: active ? AppColors.greenMid : AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textGray,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
