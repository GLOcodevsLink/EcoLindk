import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/strings.dart';
import '../../services/auth_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';

/// Sécurité : changement de mot de passe (réauthentification puis
/// FirebaseAuth.updatePassword).
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _authService = AuthService();

  bool _showPasswordForm = false;
  bool _savingPassword = false;

  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitPasswordChange(AppStrings s) async {
    if (!_passwordFormKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnack(s.passwordsDontMatch);
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _showPasswordForm = false);
      _showSnack(s.passwordChanged);
    } on FirebaseAuthException catch (e) {
      _showSnack(s.authError(e.code));
    } catch (_) {
      _showSnack(s.authError('unknown'));
    } finally {
      if (mounted) setState(() => _savingPassword = false);
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
              backgroundColor: AppColors.surface,
              body: Stack(
                children: [
                  const DecorativeLeaves(subtle: true),
                  SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _header(s.securityTitle),
                        const SizedBox(height: 18),
                        _actionTile(
                          icon: Icons.lock_reset_outlined,
                          title: s.securityChangePassword,
                          onTap: () =>
                              setState(() => _showPasswordForm = !_showPasswordForm),
                        ),
                        if (_showPasswordForm) ...[
                          const SizedBox(height: 12),
                          _passwordForm(s),
                        ],
                      ],
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

  Widget _header(String title) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: AppColors.heading),
        ),
        Expanded(
          child: Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading)),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: AppColors.greenBright.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: AppColors.greenDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText))),
            Icon(Icons.expand_more, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }

  Widget _passwordForm(AppStrings s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: s.currentPasswordLabel),
              validator: (v) =>
                  (v == null || v.isEmpty) ? s.requiredField : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: s.newPasswordLabel),
              validator: (v) {
                if (v == null || v.length < 8) return s.passwordTooShort;
                if (!RegExp(r'\d').hasMatch(v)) return s.passwordNeedsDigit;
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: s.confirmNewPasswordLabel),
              validator: (v) =>
                  (v == null || v.isEmpty) ? s.requiredField : null,
            ),
            const SizedBox(height: 14),
            _savingPassword
                ? const CircularProgressIndicator(
                    color: AppColors.greenMid, strokeWidth: 2.4)
                : GradientPillButton(
                    label: s.saveChanges,
                    onPressed: () => _submitPasswordChange(s)),
          ],
        ),
      ),
    );
  }
}
