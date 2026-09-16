import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/rewards_config.dart';
import '../../core/theme.dart';
import '../../models/wallet_models.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';

/// "Mes transactions" — le détail complet du Portefeuille, déplacé hors de
/// la carte principale (voir WalletScreen._heroCard, qui ne montre plus que
/// le solde FCFA + un lien vers cet écran) : deux vues basculables, comme
/// MyCollectionsScreen — l'historique des POINTS (gagnés/convertis, voir
/// WalletService.watchTransactions) et l'historique des FACTURES, c'est à
/// dire des conversions déjà soumises en FCFA (voir
/// WalletService.watchRedemptions) — deux historiques bien distincts, pas
/// mélangés dans une seule liste.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _authService = AuthService();
  final _walletService = WalletService();
  bool _showPoints = true;

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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                          Text(fr ? "Mes transactions" : "My transactions",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.heading)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: _tab(fr ? "Points" : "Points", _showPoints,
                                    () => setState(() => _showPoints = true))),
                            Expanded(
                                child: _tab(fr ? "Factures" : "Bills", !_showPoints,
                                    () => setState(() => _showPoints = false))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: uid.isEmpty
                            ? const SizedBox.shrink()
                            : (_showPoints ? _pointsHistory(uid, fr) : _billsHistory(uid, fr)),
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
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: active ? Colors.white : AppColors.textGray,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    );
  }

  Widget _pointsHistory(String uid, bool fr) {
    return StreamBuilder<List<PointsTransaction>>(
      stream: _walletService.watchTransactions(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.2));
        }
        if (snap.hasError) {
          return Center(
            child: InlineErrorBanner(
              message: fr ? "Impossible de charger l'historique." : "Couldn't load history.",
              retryLabel: fr ? "Réessayer" : "Retry",
              onRetry: () => setState(() {}),
            ),
          );
        }
        final txs = snap.data ?? const [];
        if (txs.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFFC98A00),
            title: fr ? "Aucun mouvement" : "No transactions yet",
            message: fr
                ? "Vos points gagnés et convertis apparaîtront ici."
                : "Points you earn and convert will show up here.",
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: txs.length,
          itemBuilder: (context, i) => _pointsTile(txs[i], fr),
        );
      },
    );
  }

  static const _txIcons = {
    PointsTxType.earnedCollection: Icons.recycling_rounded,
    PointsTxType.earnedReferral: Icons.group_add_rounded,
    PointsTxType.redeemed: Icons.arrow_downward_rounded,
    PointsTxType.adjustment: Icons.tune_rounded,
  };

  Widget _pointsTile(PointsTransaction t, bool fr) {
    final isCredit = t.points >= 0;
    final color = isCredit ? AppColors.greenDeep : Colors.redAccent;
    final fcfa = RewardsConfig.fcfaForPoints(t.points.abs());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // Fond de carte adapté au thème (pas de blanc en dur, demande
        // explicite : visible aussi en mode sombre).
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          BoxLogo(_txIcons[t.type] ?? Icons.tune_rounded, size: 38, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.mainText)),
                Text(_formatDate(t.createdAt),
                    style: TextStyle(fontSize: 10, color: AppColors.textGray, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${isCredit ? '+' : ''}${t.points} pts",
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
              Text("${fcfa.toStringAsFixed(0)} FCFA",
                  style: TextStyle(fontSize: 10, color: AppColors.textGray, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billsHistory(String uid, bool fr) {
    return StreamBuilder<List<RedemptionRequest>>(
      stream: _walletService.watchRedemptions(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.2));
        }
        if (snap.hasError) {
          return Center(
            child: InlineErrorBanner(
              message: fr ? "Impossible de charger les factures." : "Couldn't load bills.",
              retryLabel: fr ? "Réessayer" : "Retry",
              onRetry: () => setState(() {}),
            ),
          );
        }
        final bills = snap.data ?? const [];
        if (bills.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_outlined,
            color: AppColors.greenDeep,
            title: fr ? "Aucune facture" : "No bills yet",
            message: fr
                ? "Vos conversions de points en FCFA apparaîtront ici."
                : "Your points-to-FCFA conversions will show up here.",
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: bills.length,
          itemBuilder: (context, i) => _billTile(bills[i], fr),
        );
      },
    );
  }

  String _methodLabel(RedemptionMethod m, bool fr) => switch (m) {
        RedemptionMethod.airtime => fr ? "Crédit téléphonique" : "Airtime",
        RedemptionMethod.mobileData => fr ? "Forfait internet" : "Mobile data",
        RedemptionMethod.withdrawal => fr ? "Retrait" : "Withdrawal",
        RedemptionMethod.sendToRelative => fr ? "Envoyer à un proche" : "Send to a relative",
      };

  Color _methodColor(RedemptionMethod m) => switch (m) {
        RedemptionMethod.airtime => const Color(0xFF2094C4),
        RedemptionMethod.mobileData => const Color(0xFF7C5CBF),
        RedemptionMethod.withdrawal => AppColors.greenDeep,
        RedemptionMethod.sendToRelative => const Color(0xFFE08E2C),
      };

  IconData _methodIcon(RedemptionMethod m) => switch (m) {
        RedemptionMethod.airtime => Icons.phone_android_rounded,
        RedemptionMethod.mobileData => Icons.wifi_rounded,
        RedemptionMethod.withdrawal => Icons.account_balance_outlined,
        RedemptionMethod.sendToRelative => Icons.card_giftcard_outlined,
      };

  Widget _billTile(RedemptionRequest r, bool fr) {
    final isPending = r.status == RedemptionStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // Fond de carte adapté au thème (pas de blanc en dur, demande
        // explicite : visible aussi en mode sombre).
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          BoxLogo(_methodIcon(r.method), size: 38, color: _methodColor(r.method)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_methodLabel(r.method, fr),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.mainText)),
                Text(_formatDate(r.createdAt),
                    style: TextStyle(fontSize: 10, color: AppColors.textGray, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("-${r.amountFcfa.toStringAsFixed(0)} FCFA",
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
              Text(
                  isPending
                      ? (fr ? "En cours" : "Pending")
                      : (fr ? "Terminée" : "Completed"),
                  style: TextStyle(
                      fontSize: 10,
                      color: isPending ? AppColors.amber : AppColors.greenDeep,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
}
