import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_rating.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/wp_common.dart';
import 'rating_screen.dart';

/// Détail + fiche de traçabilité d'une collecte terminée (ou annulée) — voir
/// règle métier #10/#14/#21 : type de déchet, poids, prix/valeur, date,
/// collecteur, fournisseur, référence, statut. Écran partagé Fournisseur ET
/// Collecteur (voir CollectionHistoryScreen / CollectorHistoryScreen) : le
/// poids/valeur/points et l'action "Évaluer le collecteur" restent affichés
/// systématiquement (ce sont les données factuelles de LA collecte), sauf la
/// notation elle-même, jamais proposée à un Collecteur qui se noterait
/// lui-même.
class CollectionDetailScreen extends StatelessWidget {
  final CollectionRequest request;
  const CollectionDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final r = request;
    // Idempotent — sans effet si déjà réclamé (voir CollectionService).
    settleCompletedRequest(r);
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
                          Text(r.reference,
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                          const Spacer(),
                          RequestStatusBadge(status: r.status, fr: fr),
                        ],
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(top: 14, bottom: 20),
                          children: [
                            if (r.imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(r.imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
                              ),
                            const SizedBox(height: 16),
                            if (r.status == RequestStatus.completed) ...[
                              Row(
                                children: [
                                  Expanded(
                                      child: _metricCard(fr ? "Poids" : "Weight",
                                          "${(r.weightKg ?? 0).toStringAsFixed(1)} kg", const Color(0xFF2094C4))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _metricCard(fr ? "Valeur" : "Value",
                                          "${(r.valueFcfa ?? 0).toStringAsFixed(0)} FCFA", AppColors.greenDeep)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _metricCard(fr ? "Points" : "Points",
                                          "+${r.pointsEarned ?? 0}", const Color(0xFFC98A00))),
                                ],
                              ),
                              const SizedBox(height: 18),
                            ],
                            Text(fr ? "Fiche de traçabilité" : "Traceability record",
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                            const SizedBox(height: 10),
                            _row(fr ? "Référence" : "Reference", r.reference),
                            _row(fr ? "Type de déchet" : "Waste type", r.category.label(fr)),
                            _row(fr ? "Description" : "Description", r.description),
                            _row(fr ? "Quantité déclarée" : "Declared quantity", r.quantityRange),
                            _row(fr ? "Adresse" : "Address", r.address.isEmpty ? '—' : r.address),
                            _row(fr ? "Date de la demande" : "Request date", _formatDate(r.createdAt)),
                            if (r.completedAt != null)
                              _row(fr ? "Date de collecte" : "Collection date", _formatDate(r.completedAt!)),
                            _row(fr ? "Collecteur" : "Collector", r.collectorName ?? '—'),
                            _row(fr ? "Statut" : "Status", r.status.label(fr)),
                            const SizedBox(height: 18),
                            if (r.status == RequestStatus.completed)
                              FutureBuilder<CollectionRating?>(
                                future: RatingService().fetch(r.id),
                                builder: (context, snap) {
                                  if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
                                  final rating = snap.data;
                                  if (rating != null) {
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: AppColors.card,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: AppColors.line, width: 1.2)),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: List.generate(
                                              5,
                                              (i) => Icon(
                                                  i < rating.stars ? Icons.star_rounded : Icons.star_border_rounded,
                                                  color: Colors.amber,
                                                  size: 18),
                                            ),
                                          ),
                                          if (rating.comment.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(rating.comment, style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                                          ],
                                        ],
                                      ),
                                    );
                                  }
                                  // Jamais proposé à un Collecteur qui se
                                  // noterait lui-même — uniquement au
                                  // Fournisseur qui a posté cette demande.
                                  if (AuthService().currentUser?.uid != r.householdUid) {
                                    return const SizedBox.shrink();
                                  }
                                  return GradientPillButton(
                                    label: fr ? "Évaluer le collecteur" : "Rate the collector",
                                    onPressed: () => Navigator.of(context)
                                        .push(MaterialPageRoute(builder: (_) => RatingScreen(request: r))),
                                  );
                                },
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

  Widget _metricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.26), width: 1.2),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textGray))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.mainText)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
}
