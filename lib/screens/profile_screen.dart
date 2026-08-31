import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../widgets/decorative_leaves.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import 'onboarding/onboarding_screen.dart';

/// Page de profil : informations du compte (lues depuis Firestore) +
/// déconnexion.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final s = AppStrings.of(lang);
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          future: _userDocFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                backgroundColor: AppColors.surface,
                body: Center(child: CircularProgressIndicator(color: AppColors.greenMid)),
              );
            }
            return _buildProfile(s, snapshot.data?.data());
          },
        );
      },
    );
  }

  Widget _buildProfile(AppStrings s, Map<String, dynamic>? data) {
    final fullName = (data?['fullName'] as String?)?.trim() ?? '';
    final email = (data?['email'] as String?) ?? (_authService.currentUser?.email ?? '');
    final phone = (data?['phone'] as String?) ?? '';
    final address = data?['address'] as String?;
    final role = (data?['role'] as String?) == UserRole.collector.name
        ? UserRole.collector
        : UserRole.household;
    final verificationStatus = data?['verificationStatus'] as String?;
    final collectionZone = data?['collectionZone'] as String?;
    final workStatusStr = data?['workStatus'] as String?;
    final companyName = data?['companyName'] as String?;

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
                      icon: const Icon(Icons.arrow_back, color: AppColors.greenDark),
                    ),
                    Expanded(
                      child: Text(s.profileTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                    ),
                    const SizedBox(width: 48), // équilibre visuel avec le bouton retour
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                            gradient: AppColors.buttonGradient, shape: BoxShape.circle),
                        child: Center(
                          child: Text(_initials(fullName),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(fullName.isEmpty ? '—' : fullName,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                      const SizedBox(height: 8),
                      _roleBadge(role, verificationStatus, s),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(s.profileInfoSection,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: AppColors.textGray)),
                const SizedBox(height: 10),
                _infoTile(Icons.email_outlined, s.email, email),
                _infoTile(Icons.phone_outlined, s.phoneLabel, phone),
                if (role == UserRole.household && address != null && address.isNotEmpty)
                  _infoTile(Icons.home_outlined, s.address, address),
                if (role == UserRole.collector) ...[
                  if (collectionZone != null && collectionZone.isNotEmpty)
                    _infoTile(Icons.location_on_outlined, s.collectionZone, collectionZone),
                  if (workStatusStr != null)
                    _infoTile(
                      Icons.badge_outlined,
                      s.workStatusLabel,
                      workStatusStr == WorkStatus.company.name
                          ? s.workStatusCompany
                          : s.workStatusIndependent,
                    ),
                  if (companyName != null && companyName.isNotEmpty)
                    _infoTile(Icons.apartment_outlined, s.companyNameOptional, companyName),
                ],
                const SizedBox(height: 26),
                _isSigningOut
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4))
                    : OutlinedButton.icon(
                        onPressed: () => _confirmSignOut(s),
                        icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                        label: Text(s.logout,
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: Colors.redAccent, width: 1.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Widget _roleBadge(UserRole role, String? verificationStatus, AppStrings s) {
    final isPending = verificationStatus == 'pending';
    final color = isPending ? const Color(0xFF8A6D00) : AppColors.greenMid;
    final bg = isPending ? Colors.amber.withOpacity(0.15) : AppColors.greenBright.withOpacity(0.15);
    final statusLabel = isPending ? s.statusPending : s.statusVerified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('${role.label(s)} · $statusLabel',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
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
                color: AppColors.greenBright.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: AppColors.greenDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: AppColors.textGray, fontWeight: FontWeight.w700)),
                Text(value.isEmpty ? '—' : value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
