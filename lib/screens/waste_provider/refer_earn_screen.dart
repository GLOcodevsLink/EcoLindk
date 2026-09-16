import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import '../../core/l10n/app_language.dart';
import '../../core/rewards_config.dart';
import '../../core/theme.dart';
import '../../models/referral.dart';
import '../../services/auth_service.dart';
import '../../services/referral_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';

/// Parrainage — voir règle métier #12/#22 : un point n'est crédité au
/// parrain que lorsque le filleul termine sa première collecte qualifiante,
/// jamais à la simple inscription (voir ReferralService.creditIfQualifying).
class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  final _authService = AuthService();
  final _referralService = ReferralService();
  late final Future<String> _codeFuture;

  @override
  void initState() {
    super.initState();
    _codeFuture = _loadCode();
    // Réclame ici, dans SON PROPRE portefeuille, les points de tout filleul
    // déjà qualifié depuis la dernière visite — voir ReferralService pour
    // le pourquoi (personne d'autre que le parrain ne peut créditer son
    // portefeuille). Idempotent, sans effet si rien de nouveau.
    final uid = _authService.currentUser?.uid;
    if (uid != null) _referralService.claimPendingRewards(uid);
  }

  Future<String> _loadCode() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return '';
    final doc = await _authService.fetchUserDocument(uid);
    final firstName = (doc.data()?['firstName'] as String?) ?? '';
    return _referralService.ensureCode(uid, firstName);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUser?.uid ?? '';
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
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
                          icon: Icon(Icons.arrow_back, color: AppColors.heading),
                        ),
                        Text(fr ? "Parrainage" : "Refer & Earn",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.heading)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fr
                          ? "Invitez vos proches. Quand ils réalisent leur première collecte, vous gagnez ${RewardsConfig.referralPoints} points."
                          : "Invite your relatives. When they complete their first collection, you earn ${RewardsConfig.referralPoints} points.",
                      style: TextStyle(fontSize: 12.5, color: AppColors.textGray, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<String>(
                      future: _codeFuture,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.2)),
                          );
                        }
                        if (snap.hasError || (snap.data ?? '').isEmpty) {
                          return InlineErrorBanner(
                            message: fr
                                ? "Impossible de générer votre code."
                                : "Couldn't generate your code.",
                            retryLabel: fr ? "Réessayer" : "Retry",
                            onRetry: () => setState(() {}),
                          );
                        }
                        final code = snap.data!;
                        final link = "https://ecolindk.app/r/$code";
                        return _codeCard(code, link, fr);
                      },
                    ),
                    const SizedBox(height: 22),
                    SectionHeader(fr ? "Vos filleuls" : "Your referrals"),
                    if (uid.isNotEmpty)
                      StreamBuilder<Map<String, dynamic>?>(
                        stream: _referralService.watchSummary(uid),
                        builder: (context, summarySnap) {
                          final count = (summarySnap.data?['referralsCount'] as num?)?.toInt() ?? 0;
                          final earned = (summarySnap.data?['pointsEarned'] as num?)?.toInt() ?? 0;
                          return Row(
                            children: [
                              Expanded(
                                  child: _statBox(fr ? "Filleuls réussis" : "Successful referrals",
                                      "$count", const Color(0xFF2094C4), Icons.groups_rounded)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _statBox(fr ? "Points gagnés" : "Points earned", "$earned",
                                      const Color(0xFFC98A00), Icons.emoji_events_rounded)),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 14),
                    if (uid.isNotEmpty)
                      StreamBuilder<List<ReferralUse>>(
                        stream: _referralService.watchHistory(uid),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                  child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.2)),
                            );
                          }
                          final uses = snap.data ?? const [];
                          if (uses.isEmpty) {
                            return EmptyState(
                              icon: Icons.groups_outlined,
                              color: const Color(0xFF7C5CBF),
                              title: fr ? "Aucun filleul pour l'instant" : "No referrals yet",
                              message: fr
                                  ? "Partagez votre code pour commencer à gagner des points."
                                  : "Share your code to start earning points.",
                            );
                          }
                          return Column(children: uses.map((u) => _referralTile(u, fr)).toList());
                        },
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
  }

  Widget _codeCard(String code, String link, bool fr) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fr ? "Votre code de parrainage" : "Your referral code",
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(code,
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(fr ? "Code copié !" : "Code copied!")));
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(fr ? "Copier" : "Copy"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Share.share(
                    fr
                        ? "Rejoins-moi sur EcoLindk et valorise tes déchets recyclables ! Utilise mon code $code ou ce lien : $link"
                        : "Join me on EcoLindk and turn your recyclable waste into value! Use my code $code or this link: $link",
                  ),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: Text(fr ? "Partager" : "Share"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.28), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoxLogo(icon, size: 32),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 10.5, color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _referralTile(ReferralUse u, bool fr) {
    final qualified = u.status == ReferralStatus.qualified;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.line,
            child: Icon(Icons.person, size: 16, color: AppColors.textGray),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(u.referredName.isEmpty ? (fr ? "Filleul" : "Referral") : u.referredName,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.mainText)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: (qualified ? AppColors.greenMid : Colors.amber).withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              qualified
                  ? (fr ? "+${u.pointsAwarded} pts" : "+${u.pointsAwarded} pts")
                  : (fr ? "En attente" : "Pending"),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: qualified ? AppColors.greenDeep : const Color(0xFFB07E00)),
            ),
          ),
        ],
      ),
    );
  }
}
