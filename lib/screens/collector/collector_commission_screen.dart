import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';
import 'subscription_screen.dart';

/// Vue d'ensemble de la commission du Collecteur — demande explicite :
/// "there is also a commission fee that will be paid by the collector each
/// month based on all the transactions he did in a month" / "if you think
/// there should be a page for the collector to view all the things for the
/// commission fee do it".
///
/// Le CALCUL de la commission (taux, base — sur le prix payé au fournisseur,
/// sur le nombre de collectes…) n'est PAS encore défini (demande explicite :
/// "we are going to work on the way in which we will calculate the
/// commission fee" séparément) — cet écran affiche donc les données brutes
/// dont ce calcul aura besoin (collectes terminées du mois, total payé aux
/// fournisseurs) sans inventer de taux, avec une note "à définir" plutôt
/// qu'un chiffre qui laisserait croire à une vraie facturation.
class CollectorCommissionScreen extends StatelessWidget {
  const CollectorCommissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final collectionService = CollectionService();
    final uid = authService.currentUser?.uid ?? '';
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: appLanguage,
          builder: (context, lang, _) {
            final fr = lang == AppLanguage.fr;
            final now = DateTime.now();
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
                              Text(fr ? "Commission" : "Commission",
                                  style: TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                            ],
                          ),
                          Expanded(
                            child: uid.isEmpty
                                ? const SizedBox.shrink()
                                : StreamBuilder<List<CollectionRequest>>(
                                    stream: collectionService.watchCollectorHistory(uid),
                                    builder: (context, snap) {
                                      if (snap.connectionState == ConnectionState.waiting) {
                                        return const Center(
                                            child: CircularProgressIndicator(
                                                color: AppColors.greenMid, strokeWidth: 2.4));
                                      }
                                      final all = snap.data ?? const [];
                                      final thisMonth = all
                                          .where((r) =>
                                              r.status == RequestStatus.completed &&
                                              r.completedAt != null &&
                                              r.completedAt!.year == now.year &&
                                              r.completedAt!.month == now.month)
                                          .toList();
                                      final total = thisMonth.fold<double>(
                                          0, (sum, r) => sum + (r.valueFcfa ?? 0));

                                      return ListView(
                                        padding: const EdgeInsets.only(top: 14, bottom: 20),
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                                gradient: AppColors.buttonGradient,
                                                borderRadius: BorderRadius.circular(20)),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(_monthLabel(now, fr),
                                                    style: const TextStyle(
                                                        color: Colors.white70, fontSize: 11)),
                                                const SizedBox(height: 4),
                                                Text(
                                                    "${thisMonth.length} "
                                                    "${fr ? "collecte(s) terminée(s)" : "completed pickup(s)"}",
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w800)),
                                                const SizedBox(height: 14),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _stat(
                                                          fr ? "Total payé aux fournisseurs" : "Total paid to providers",
                                                          "${total.toStringAsFixed(0)} FCFA"),
                                                    ),
                                                    Expanded(
                                                      child: _stat(
                                                          fr ? "Commission due" : "Commission due",
                                                          fr ? "À définir" : "To be defined"),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            child: Text(
                                                fr
                                                    ? "Le mode de calcul de la commission mensuelle n'est pas encore défini — cette page sera mise à jour dès qu'il le sera."
                                                    : "How the monthly commission is calculated hasn't been defined yet — this page will be updated once it is.",
                                                style: TextStyle(
                                                    fontSize: 11.5, color: AppColors.textGray, height: 1.4)),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(fr ? "Transactions du mois" : "This month's transactions",
                                              style: TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                                          const SizedBox(height: 10),
                                          if (thisMonth.isEmpty)
                                            EmptyState(
                                              icon: Icons.receipt_long_outlined,
                                              color: const Color(0xFF17A398),
                                              title: fr ? "Aucune transaction ce mois-ci" : "No transaction this month",
                                              message: fr
                                                  ? "Vos collectes terminées ce mois-ci apparaîtront ici."
                                                  : "Your pickups completed this month will show up here.",
                                            )
                                          else
                                            ...thisMonth.map((r) => _tile(r, fr)),
                                          const SizedBox(height: 20),
                                          OutlinedButton.icon(
                                            onPressed: () => Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                                            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                                            label: Text(fr ? "Voir les offres Premium" : "See Premium plans"),
                                          ),
                                          const SizedBox(height: 20),
                                        ],
                                      );
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

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _tile(CollectionRequest r, bool fr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(r.category.icon, color: AppColors.greenMid),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.category.label(fr),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                Text("${(r.weightKg ?? 0).toStringAsFixed(1)} kg",
                    style: TextStyle(fontSize: 10.5, color: AppColors.textGray)),
              ],
            ),
          ),
          Text("${(r.valueFcfa ?? 0).toStringAsFixed(0)} FCFA",
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
        ],
      ),
    );
  }

  String _monthLabel(DateTime now, bool fr) {
    const frMonths = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
      'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    const enMonths = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    return fr
        ? "${frMonths[now.month - 1]} ${now.year}"
        : "${enMonths[now.month - 1]} ${now.year}";
  }
}
