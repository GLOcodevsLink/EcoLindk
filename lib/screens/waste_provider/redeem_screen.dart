import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/rewards_config.dart';
import '../../core/theme.dart';
import '../../models/wallet_models.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/wp_common.dart';

/// Flux de conversion des points (crédit téléphonique / forfait internet /
/// retrait / envoi à un proche) — **simulé** : voir WalletService.redeem
/// pour le pourquoi (pas encore d'API de paiement/mobile money branchée).
/// Débite néanmoins réellement le solde de points dans Firestore.
class RedeemScreen extends StatefulWidget {
  final RedemptionMethod method;
  const RedeemScreen({super.key, required this.method});

  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  final _authService = AuthService();
  final _walletService = WalletService();
  final _phoneController = TextEditingController();

  int? _selectedPoints;
  bool _isSubmitting = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _methodLabel(bool fr) => switch (widget.method) {
        RedemptionMethod.airtime => fr ? "Crédit téléphonique" : "Airtime",
        RedemptionMethod.mobileData => fr ? "Forfait internet" : "Mobile data",
        RedemptionMethod.withdrawal => fr ? "Retrait" : "Withdrawal",
        RedemptionMethod.sendToRelative => fr ? "Envoyer à un proche" : "Send to a relative",
      };

  // Mêmes couleurs que sur le Portefeuille/l'Accueil — une seule et même
  // palette pour un même concept, jamais recalculée différemment ailleurs.
  Color get _methodColor => switch (widget.method) {
        RedemptionMethod.airtime => const Color(0xFF2094C4),
        RedemptionMethod.mobileData => const Color(0xFF7C5CBF),
        RedemptionMethod.withdrawal => AppColors.greenDeep,
        RedemptionMethod.sendToRelative => const Color(0xFFE08E2C),
      };

  IconData get _methodIcon => switch (widget.method) {
        RedemptionMethod.airtime => Icons.phone_android_rounded,
        RedemptionMethod.mobileData => Icons.wifi_rounded,
        RedemptionMethod.withdrawal => Icons.account_balance_outlined,
        RedemptionMethod.sendToRelative => Icons.card_giftcard_outlined,
      };

  bool get _needsPhone =>
      widget.method == RedemptionMethod.airtime ||
      widget.method == RedemptionMethod.mobileData ||
      widget.method == RedemptionMethod.sendToRelative;

  Future<void> _confirm(bool fr, int balance) async {
    final uid = _authService.currentUser?.uid;
    final points = _selectedPoints;
    if (points == null) {
      setState(() => _error = fr ? "Choisissez un nombre de points." : "Choose an amount of points.");
      return;
    }
    if (uid == null) return;
    if (_needsPhone && _phoneController.text.trim().isEmpty) {
      setState(() => _error = fr ? "Entrez un numéro de téléphone." : "Enter a phone number.");
      return;
    }
    if (points > balance) {
      setState(() => _error = fr ? "Solde de points insuffisant." : "Not enough points.");
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _walletService.redeem(
        uid: uid,
        method: widget.method,
        points: points,
        recipientPhone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _done = true;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = fr ? "Une erreur est survenue. Réessayez." : "Something went wrong. Please try again.";
      });
    }
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                          BoxLogo(_methodIcon, size: 34),
                          const SizedBox(width: 10),
                          Text(_methodLabel(fr),
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.heading)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _done
                            ? _successView(fr)
                            : uid.isEmpty
                                ? const SizedBox.shrink()
                                : StreamBuilder<int>(
                                    stream: _walletService.watchBalance(uid),
                                    builder: (context, snap) {
                                      final balance = snap.data ?? 0;
                                      return _form(fr, balance);
                                    },
                                  ),
                      ),
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

  Widget _form(bool fr, int balance) {
    final options = [10, 20, 50, balance].where((p) => p > 0).toSet().toList()..sort();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _methodColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _methodColor.withOpacity(0.25), width: 1.2),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: _methodColor, size: 20),
                const SizedBox(width: 10),
                Text(fr ? "Solde : $balance pts" : "Balance: $balance pts",
                    style: TextStyle(fontWeight: FontWeight.w800, color: _methodColor)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(fr ? "Combien de points convertir ?" : "How many points to convert?",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.mainText)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((p) => ChoiceChip(
                      label: Text("$p pts",
                          style: TextStyle(
                              color: _selectedPoints == p ? _methodColor : AppColors.heading,
                              fontWeight: FontWeight.w700)),
                      selected: _selectedPoints == p,
                      onSelected: (_) => setState(() => _selectedPoints = p),
                      selectedColor: _methodColor.withOpacity(0.18),
                      side: BorderSide(
                          color: _selectedPoints == p ? _methodColor.withOpacity(0.5) : AppColors.line),
                    ))
                .toList(),
          ),
          if (_selectedPoints != null) ...[
            const SizedBox(height: 10),
            Text(
              fr
                  ? "≈ ${RewardsConfig.fcfaForPoints(_selectedPoints!).toStringAsFixed(0)} FCFA"
                  : "≈ ${RewardsConfig.fcfaForPoints(_selectedPoints!).toStringAsFixed(0)} FCFA",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.greenDeep),
            ),
          ],
          if (_needsPhone) ...[
            const SizedBox(height: 18),
            Text(
                widget.method == RedemptionMethod.sendToRelative
                    ? (fr ? "Numéro du proche" : "Relative's number")
                    : (fr ? "Votre numéro" : "Your number"),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.mainText)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "+237 6XX XXX XXX",
                prefixIcon: const Icon(Icons.phone_outlined, size: 19),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            InlineErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          _isSubmitting
              ? const Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4))
              : GradientPillButton(
                  label: fr ? "Confirmer" : "Confirm",
                  onPressed: () => _confirm(fr, balance),
                ),
        ],
      ),
    );
  }

  Widget _successView(bool fr) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.greenBright.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(Icons.check_circle, color: AppColors.greenMid, size: 40),
          ),
          const SizedBox(height: 16),
          Text(fr ? "Conversion effectuée !" : "Conversion completed!",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.mainText)),
          const SizedBox(height: 6),
          Text(
            fr
                ? "${_selectedPoints ?? 0} points convertis en ${RewardsConfig.fcfaForPoints(_selectedPoints ?? 0).toStringAsFixed(0)} FCFA."
                : "${_selectedPoints ?? 0} points converted to ${RewardsConfig.fcfaForPoints(_selectedPoints ?? 0).toStringAsFixed(0)} FCFA.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textGray),
          ),
          const SizedBox(height: 24),
          GradientPillButton(label: fr ? "Terminé" : "Done", onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
