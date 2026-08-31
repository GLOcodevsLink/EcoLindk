import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../widgets/decorative_leaves.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import 'collector_setup_screen.dart';
import 'home_screen.dart';

/// Affichée juste après la création du compte (email/mot de passe + numéro
/// vérifié) : l'utilisateur choisit son rôle, Ménage ou Collecteur.
/// - Ménage : le compte est immédiatement finalisé ("verified") -> dashboard.
/// - Collecteur : une étape de plus ([CollectorSetupScreen]) avant de
///   finaliser le compte (statut "pending").
///
/// Le compte existe déjà à ce stade : on ne peut pas revenir en arrière.
class RoleSelectionScreen extends StatefulWidget {
  final String uid;
  final String firstName;
  const RoleSelectionScreen({super.key, required this.uid, required this.firstName});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _selectHousehold(AppStrings s) async {
    setState(() => _isLoading = true);
    try {
      await _authService.completeHouseholdRegistration(widget.uid);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.authError('unknown'))));
    }
  }

  void _selectCollector() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectorSetupScreen(uid: widget.uid, firstName: widget.firstName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final s = AppStrings.of(lang);
        return PopScope(
          canPop: false,
          child: Scaffold(
            body: Stack(
              children: [
                const DecorativeLeaves(subtle: true),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.chooseRoleTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                        const SizedBox(height: 6),
                        Text(s.chooseRoleSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
                        const SizedBox(height: 28),
                        if (_isLoading)
                          const CircularProgressIndicator(color: AppColors.greenMid)
                        else
                          ...UserRole.values.map(
                            (role) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _roleCard(
                                role,
                                s,
                                onTap: role == UserRole.household
                                    ? () => _selectHousehold(s)
                                    : _selectCollector,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roleCard(UserRole role, AppStrings s, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(role.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(role.label(s),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }
}
