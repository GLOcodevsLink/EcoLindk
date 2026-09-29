import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';

/// Page d'abonnement Premium du Collecteur (demande explicite : "there
/// should be a subscription page because the collector will subscribe to
/// premium for more usage").
///
/// Aucun paiement n'est encore intégré (demande explicite : "lorsque l'on
/// clique sur le bouton abonnement ça ne doit rien faire pour le moment") —
/// "S'abonner" est volontairement inactif et n'écrit rien, jusqu'au
/// branchement du prestataire de paiement. Les fonctionnalités réservées au
/// Premium ne sont pas encore définies (demande explicite : "I have not yet
/// thought about which functionalities will be reserved for premium") — la
/// liste ci-dessous est donc volontairement générique/provisoire, à
/// affiner avec l'utilisateur.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  Widget build(BuildContext context) {
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
                              Text(fr ? "Abonnement" : "Subscription",
                                  style: TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                            ],
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.only(top: 14, bottom: 20),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFB8860B), Color(0xFFE0B04A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.workspace_premium_rounded,
                                          color: Colors.white, size: 32),
                                      const SizedBox(height: 10),
                                      Text(fr ? "Collecteur Premium" : "Collector Premium",
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text(
                                          fr
                                              ? "Un abonnement mensuel pour aller plus loin — détails à venir."
                                              : "A monthly plan to go further — details coming soon.",
                                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(fr ? "Ce que Premium pourra inclure" : "What Premium may include",
                                    style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                                const SizedBox(height: 4),
                                Text(
                                    fr
                                        ? "Liste provisoire — pas encore définitive."
                                        : "Provisional list — not final yet.",
                                    style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                                const SizedBox(height: 12),
                                _perk(fr ? "Rayon de recherche étendu sur la carte" : "Extended search radius on the map",
                                    Icons.map_outlined),
                                _perk(
                                    fr
                                        ? "Priorité de notification sur les nouveaux posts proches"
                                        : "Priority notification on new nearby posts",
                                    Icons.notifications_active_outlined),
                                _perk(fr ? "Statistiques avancées de collecte" : "Advanced pickup statistics",
                                    Icons.bar_chart_outlined),
                                const SizedBox(height: 24),
                                // Inactif tant que le paiement n'est pas intégré.
                                GradientPillButton(
                                  label: fr ? "S'abonner" : "Subscribe",
                                  onPressed: () {},
                                ),
                              ],
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

  Widget _perk(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.greenBright.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.greenDeep),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.mainText)),
          ),
        ],
      ),
    );
  }
}
