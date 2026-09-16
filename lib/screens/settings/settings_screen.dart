import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/strings.dart';
import '../../models/user_role.dart';
import '../profile_screen.dart';
import '../waste_provider/info_pages.dart';
import '../waste_provider/refer_earn_screen.dart';
import 'account_screen.dart';
import 'appearance_screen.dart';
import 'notifications_screen.dart';
import 'security_screen.dart';

/// Hub des réglages, ouvert depuis l'onglet "Réglages" de la barre de
/// navigation basse (voir home_screen.dart). En haut : avatar + nom,
/// tapotable pour ouvrir [ProfileScreen] (modification du profil). En
/// dessous : Sécurité / Notifications / Mode d'affichage / Compte, chacun
/// ouvrant sa propre page (façon WhatsApp).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  Future<DocumentSnapshot<Map<String, dynamic>>?>? _userDocFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final uid = _authService.currentUser?.uid;
    setState(() {
      _userDocFuture =
          uid == null ? Future.value(null) : _authService.fetchUserDocument(uid);
    });
  }

  Future<void> _openProfile() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    // Le nom/l'avatar peuvent avoir changé pendant l'édition.
    _reload();
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
                final data = snapshot.data?.data();
                final fullName = (data?['fullName'] as String?)?.trim() ?? '';
                final email = (data?['email'] as String?) ??
                    (_authService.currentUser?.email ?? '');
                final isHousehold = (data?['role'] as String?) != UserRole.collector.name;

                return Scaffold(
                  backgroundColor: AppColors.surface,
                  body: Stack(
                    children: [
                      const DecorativeLeaves(subtle: true),
                      SafeArea(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          children: [
                            Text(s.settingsTitle,
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.heading)),
                            const SizedBox(height: 18),
                            _profileHeader(fullName, email),
                            const SizedBox(height: 22),
                            if (isHousehold) ...[
                              _row(
                                icon: Icons.help_outline_rounded,
                                title: lang == AppLanguage.fr ? "Comment ça marche" : "How it works",
                                subtitle: lang == AppLanguage.fr
                                    ? "Le parcours du Fournisseur de déchets"
                                    : "The Waste Provider's journey",
                                onTap: () => _push(const HowItWorksScreen()),
                              ),
                              _row(
                                icon: Icons.card_giftcard_outlined,
                                title: lang == AppLanguage.fr ? "Parrainage" : "Refer & Earn",
                                subtitle: lang == AppLanguage.fr
                                    ? "Invitez vos proches, gagnez des points"
                                    : "Invite your relatives, earn points",
                                onTap: () => _push(const ReferEarnScreen()),
                              ),
                              _row(
                                icon: Icons.trending_up_rounded,
                                title: lang == AppLanguage.fr ? "Taux de conversion" : "Conversion rates",
                                subtitle: lang == AppLanguage.fr
                                    ? "Points, FCFA, parrainage"
                                    : "Points, FCFA, referrals",
                                onTap: () => _push(const ConversionRatesScreen()),
                              ),
                              _row(
                                icon: Icons.receipt_long_outlined,
                                title: lang == AppLanguage.fr ? "Liste des prix" : "Price list",
                                subtitle: lang == AppLanguage.fr
                                    ? "Prix de référence par kg"
                                    : "Reference prices per kg",
                                onTap: () => _push(const PriceListScreen()),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _row(
                              icon: Icons.security_outlined,
                              title: s.settingsRowSecurity,
                              subtitle: s.settingsRowSecuritySubtitle,
                              onTap: () => _push(const SecurityScreen()),
                            ),
                            _row(
                              icon: Icons.notifications_outlined,
                              title: s.settingsRowNotifications,
                              subtitle: s.settingsRowNotificationsSubtitle,
                              onTap: () => _push(const NotificationsScreen()),
                            ),
                            _row(
                              icon: Icons.dark_mode_outlined,
                              title: s.settingsRowAppearance,
                              subtitle: s.settingsRowAppearanceSubtitle,
                              onTap: () => _push(const AppearanceScreen()),
                            ),
                            _row(
                              icon: Icons.manage_accounts_outlined,
                              title: s.settingsRowAccount,
                              subtitle: s.settingsRowAccountSubtitle,
                              onTap: () => _push(const AccountScreen()),
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

  Widget _profileHeader(String fullName, String email) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openProfile,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                  gradient: AppColors.buttonGradient, shape: BoxShape.circle),
              child: Center(
                child: Text(_initials(fullName),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName.isEmpty ? '—' : fullName,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainText)),
                  const SizedBox(height: 2),
                  Text(email,
                      style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line, width: 1.2),
          ),
          child: Row(
            children: [
              BoxLogo(icon, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mainText)),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textGray),
            ],
          ),
        ),
      ),
    );
  }
}
