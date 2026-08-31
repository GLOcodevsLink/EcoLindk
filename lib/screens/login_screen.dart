import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/phone_field.dart';
import '../widgets/language_switcher.dart';
import '../widgets/app_logo.dart';
import '../widgets/decorative_leaves.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscure = true;
  bool _useEmail = true; // onglet actif : Email ou Téléphone
  bool _isLoading = false;

  Future<void> _submit(AppStrings s) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_useEmail) {
      // La connexion par téléphone n'est pas encore branchée à Firebase.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.phoneLoginUnavailable)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.authError(e.code))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.authError('unknown'))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: LanguageSwitcher(iconColor: AppColors.greenDark),
                    ),
                    const SizedBox(height: 4),
                    const Center(child: AppLogo(width: 170)),
                    const SizedBox(height: 20),
                    Text(s.loginTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.greenDark)),
                    const SizedBox(height: 4),
                    Text(s.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
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
                          Expanded(child: _tab(s.emailTab, _useEmail, () => setState(() => _useEmail = true))),
                          Expanded(child: _tab(s.phoneTab, !_useEmail, () => setState(() => _useEmail = false))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_useEmail)
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: lang == AppLanguage.fr ? "Entrez votre email" : "Enter your email",
                          prefixIcon: const Icon(Icons.email_outlined, size: 19),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? s.requiredField : null,
                      )
                    else
                      PhoneField(controller: _phoneController),

                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: lang == AppLanguage.fr ? "Votre mot de passe" : "Your password",
                        prefixIcon: const Icon(Icons.lock_outline, size: 19),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? s.requiredField : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(s.forgotPassword,
                            style: const TextStyle(color: AppColors.greenMid, fontWeight: FontWeight.w700, fontSize: 12.5)),
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
                        : GradientPillButton(label: s.logIn, onPressed: () => _submit(s)),
                    const SizedBox(height: 22),
                    Row(children: [
                      const Expanded(child: Divider(color: AppColors.line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(s.continueWith,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textGray)),
                      ),
                      const Expanded(child: Divider(color: AppColors.line)),
                    ]),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _socialButton("Google", Icons.g_mobiledata, Colors.redAccent)),
                        const SizedBox(width: 12),
                        Expanded(child: _socialButton("Facebook", Icons.facebook, Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: AppColors.textGray),
                          children: [
                            TextSpan(text: s.newToApp),
                            TextSpan(
                              text: s.createAccount,
                              style: const TextStyle(color: AppColors.greenMid, fontWeight: FontWeight.w800),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
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

  Widget _socialButton(String label, IconData icon, Color color) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line, width: 1.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
