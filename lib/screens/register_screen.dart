import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/phone_field.dart';
import '../widgets/language_switcher.dart';
import '../widgets/decorative_leaves.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

/// Inscription en 3 étapes :
/// 1. Identité — prénom, nom, email, mot de passe.
/// 2. Adresse.
/// 3. Téléphone (vérification par SMS) + acceptation des conditions ->
///    création du compte Firebase (email/mot de passe + numéro lié).
///
/// Le rôle (Ménage/Collecteur) n'est pas demandé ici : une fois le compte
/// créé, l'utilisateur choisit son rôle sur [RoleSelectionScreen].
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

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
  final _otpCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _obscureConfirmPw = true;
  bool _acceptTerms = false;

  final _authService = AuthService();

  String _fullPhoneNumber = '';
  bool _isSendingCode = false;
  bool _isCodeSent = false;
  bool _isPhoneVerified = false;
  bool _isCreatingAccount = false;

  // Renseignés par AuthService.verifyPhoneNumber (vrai flow Firebase Phone
  // Auth) : l'ID de vérification sert à reconstruire le credential une fois
  // le code SMS saisi ; le resend token permet de renvoyer un code sans
  // relancer toute la vérification depuis zéro.
  String? _verificationId;
  int? _resendToken;
  PhoneAuthCredential? _phoneCredential;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  /// Envoie un vrai code SMS via Firebase Phone Auth (`AuthService.
  /// verifyPhoneNumber`) pour vérifier l'identité du collecteur (ou du
  /// ménage) avant la création du compte.
  Future<void> _sendCode(AppStrings s) async {
    if (_phoneCtrl.text.isEmpty) {
      _showSnack(s.requiredField);
      return;
    }
    setState(() => _isSendingCode = true);
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        forceResendingToken: _resendToken,
        // Sur Android, Play Services peut vérifier le numéro automatiquement
        // (sans saisie de code) : le credential est alors déjà valide.
        onAutoVerified: (credential) {
          if (!mounted) return;
          setState(() {
            _phoneCredential = credential;
            _isPhoneVerified = true;
            _isCodeSent = true;
            _isSendingCode = false;
          });
        },
        onFailed: (e) {
          if (!mounted) return;
          setState(() => _isSendingCode = false);
          _showSnack(s.authError(e.code));
        },
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isCodeSent = true;
            _isSendingCode = false;
          });
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSendingCode = false);
      _showSnack(s.authError('unknown'));
    }
  }

  void _verifyCode(AppStrings s) {
    if (_otpCtrl.text.length != 6) {
      _showSnack(s.codeTooShort);
      return;
    }
    if (_verificationId == null) {
      _showSnack(s.authError('session-expired'));
      return;
    }
    // Construit le credential à partir du code saisi ; sa validité n'est
    // vérifiée par Firebase qu'au moment où il est effectivement lié au
    // compte (dans _createAccount), ce qui remonte alors une éventuelle
    // erreur 'invalid-verification-code' ou 'session-expired'.
    setState(() {
      _phoneCredential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      _isPhoneVerified = true;
    });
  }

  Future<void> _createAccount(AppStrings s) async {
    if (!_isPhoneVerified) {
      _showSnack(s.codeRequired);
      return;
    }
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
        phoneCredential: _phoneCredential,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoleSelectionScreen(
            uid: credential.user!.uid,
            firstName: _firstNameCtrl.text.trim(),
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
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
                            icon: const Icon(Icons.arrow_back, color: AppColors.greenDark),
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
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.logoGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.eco, color: Colors.white, size: 19),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _StepIndicator(step: _step, total: _totalSteps, label: s.stepOf(_step + 1, _totalSteps)),
                      const SizedBox(height: 14),
                      Text(s.registerTitle,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                      const SizedBox(height: 4),
                      Text(s.registerSubtitle,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
                      const SizedBox(height: 18),
                      Expanded(
                        child: SingleChildScrollView(
                          child: switch (_step) {
                            0 => _identityStep(s),
                            1 => _addressStep(s),
                            _ => _phoneStep(s),
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isCreatingAccount || _isSendingCode
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4),
                            )
                          : GradientPillButton(
                              label: _step == 2 ? s.createMyAccount : s.next,
                              onPressed: _step == 2 ? () => _createAccount(s) : () => _goNext(lang),
                            ),
                      const SizedBox(height: 18),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: AppColors.textGray),
                            children: [
                              TextSpan(text: s.alreadyAccount),
                              TextSpan(
                                text: s.logIn,
                                style: const TextStyle(color: AppColors.greenMid, fontWeight: FontWeight.w800),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
  }

  Widget _identityStep(AppStrings s) {
    return Form(
      key: _identityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _field(_firstNameCtrl, s.firstName, Icons.person_outline, s)),
              const SizedBox(width: 12),
              Expanded(child: _field(_lastNameCtrl, s.lastName, Icons.person_outline, s)),
            ],
          ),
          const SizedBox(height: 14),
          _field(_emailCtrl, s.email, Icons.email_outlined, s, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          _passwordFields(s),
        ],
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
          const SizedBox(height: 4),
          Text(s.addressStepSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
        const SizedBox(height: 4),
        Text(s.phoneStepSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
        const SizedBox(height: 16),
        PhoneField(
          controller: _phoneCtrl,
          onChanged: (full) => _fullPhoneNumber = full,
        ),
        const SizedBox(height: 14),

        if (_isPhoneVerified)
          _infoBanner(s.phoneVerifiedLabel, icon: Icons.check_circle_outline)
        else if (!_isCodeSent)
          _isSendingCode
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4))
              : GradientPillButton(
                  label: s.sendCode,
                  outlined: true,
                  trailingIcon: null,
                  onPressed: () => _sendCode(s),
                )
        else ...[
          Text(s.codeSentTo(_fullPhoneNumber),
              style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: s.verificationCode,
              counterText: '',
              prefixIcon: const Icon(Icons.sms_outlined, size: 19),
            ),
          ),
          const SizedBox(height: 10),
          GradientPillButton(
            label: s.verifyCode,
            outlined: true,
            trailingIcon: null,
            onPressed: () => _verifyCode(s),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _isSendingCode ? null : () => _sendCode(s),
              child: Text(s.resendCode,
                  style: const TextStyle(
                      color: AppColors.greenMid, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
        ],

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
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textGray, height: 1.4)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, AppStrings s,
      {TextInputType? keyboardType}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19)),
      validator: (v) => (v == null || v.isEmpty) ? s.requiredField : null,
    );
  }

  Widget _passwordFields(AppStrings s) {
    return Column(
      children: [
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePw,
          decoration: InputDecoration(
            labelText: s.passwordLabel,
            prefixIcon: const Icon(Icons.lock_outline, size: 19),
            suffixIcon: IconButton(
              icon: Icon(_obscurePw ? Icons.visibility_outlined : Icons.visibility_off_outlined),
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
          decoration: InputDecoration(
            labelText: s.confirmPassword,
            prefixIcon: const Icon(Icons.lock_outline, size: 19),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPw ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscureConfirmPw = !_obscureConfirmPw),
            ),
          ),
          validator: (v) => (v == null || v.isEmpty) ? s.confirmationRequired : null,
        ),
      ],
    );
  }

  Widget _infoBanner(String text, {IconData icon = Icons.info_outline}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenBright.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greenMid.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.greenMid),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.greenDark, height: 1.4, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Petit indicateur de progression (une barre par étape) pour le formulaire.
class _StepIndicator extends StatelessWidget {
  final int step; // 0-based
  final int total;
  final String label;
  const _StepIndicator({required this.step, required this.total, required this.label});

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
            style: const TextStyle(fontSize: 11, color: AppColors.textGray, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
