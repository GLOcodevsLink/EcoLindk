import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/strings.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../onboarding/onboarding_screen.dart';

/// Compte : infos en lecture seule, déconnexion, et suppression définitive
/// du compte (zone de danger — réauthentification par mot de passe requise).
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _authService = AuthService();
  late final Future<DocumentSnapshot<Map<String, dynamic>>?> _userDocFuture;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    _userDocFuture =
        uid == null ? Future.value(null) : _authService.fetchUserDocument(uid);
  }

  Future<void> _confirmSignOut(AppStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.logoutConfirmTitle),
        content: Text(s.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.logout,
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  /// Demande une réauthentification — mot de passe si le compte en a un
  /// ([AuthService.hasPasswordProvider]), sinon rouvre le sélecteur Google —
  /// puis supprime le compte via [AuthService.deleteAccount].
  Future<void> _confirmDeleteAccount(AppStrings s, String? phone) async {
    final usesPassword = _authService.hasPasswordProvider;
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isDeleting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(s.deleteAccountConfirmTitle),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.deleteAccountWarning,
                    style: TextStyle(color: AppColors.textGray, fontSize: 12.5)),
                const SizedBox(height: 14),
                if (usesPassword) ...[
                  Text(s.enterPasswordToConfirm,
                      style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    autofocus: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? s.requiredField : null,
                  ),
                ] else
                  Text(s.confirmWithGoogleToDelete,
                      style: TextStyle(fontSize: 12, color: AppColors.textGray)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.of(ctx).pop(false),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (usesPassword && !formKey.currentState!.validate()) {
                        return;
                      }
                      setDialogState(() => isDeleting = true);
                      try {
                        await _authService.deleteAccount(
                          password: usesPassword ? passwordController.text : null,
                          phone: phone,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => isDeleting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(s.authError(e.code))));
                        }
                      } catch (_) {
                        setDialogState(() => isDeleting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(s.authError('unknown'))));
                        }
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.redAccent))
                  : Text(s.deleteAccountAction,
                      style: const TextStyle(
                          color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
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
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: _userDocFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Scaffold(
                    backgroundColor: AppColors.surface,
                    body: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.greenMid)),
                  );
                }
                final data = snapshot.data?.data();
                final fullName = (data?['fullName'] as String?)?.trim() ?? '';
                final email = (data?['email'] as String?) ??
                    (_authService.currentUser?.email ?? '');
                final phone = (data?['phone'] as String?) ?? '';
                final role = (data?['role'] as String?) == UserRole.collector.name
                    ? UserRole.collector
                    : UserRole.household;
                final verificationStatus =
                    data?['verificationStatus'] as String?;

                return Scaffold(
                  backgroundColor: AppColors.surface,
                  body: Stack(
                    children: [
                      const DecorativeLeaves(subtle: true),
                      SafeArea(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(Icons.arrow_back,
                                      color: AppColors.heading),
                                ),
                                Expanded(
                                  child: Text(s.accountTitle,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.heading)),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _infoTile(Icons.badge_outlined, s.fullName,
                                fullName.isEmpty ? '—' : fullName),
                            _infoTile(Icons.email_outlined, s.email, email),
                            _infoTile(Icons.phone_outlined, s.phoneLabel,
                                phone.isEmpty ? '—' : phone),
                            _infoTile(role.icon, s.signUpAs, role.label(s)),
                            _infoTile(
                              Icons.verified_user_outlined,
                              s.workStatusLabel,
                              verificationStatus == 'pending'
                                  ? s.statusPending
                                  : s.statusVerified,
                            ),
                            const SizedBox(height: 22),
                            _isSigningOut
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.greenMid,
                                        strokeWidth: 2.4))
                                : OutlinedButton.icon(
                                    onPressed: () => _confirmSignOut(s),
                                    icon: const Icon(Icons.logout,
                                        size: 18, color: Colors.redAccent),
                                    label: Text(s.logout,
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                      side: const BorderSide(
                                          color: Colors.redAccent, width: 1.4),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999)),
                                    ),
                                  ),
                            const SizedBox(height: 28),
                            Text(s.dangerZone,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: Colors.redAccent)),
                            const SizedBox(height: 8),
                            Text(s.deleteAccountWarning,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textGray,
                                    height: 1.4)),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _confirmDeleteAccount(s, phone),
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.redAccent),
                              label: Text(s.deleteAccount,
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                side: const BorderSide(
                                    color: Colors.redAccent, width: 1.4),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999)),
                              ),
                            ),
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
      },
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textGray,
                        fontWeight: FontWeight.w700)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mainText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
