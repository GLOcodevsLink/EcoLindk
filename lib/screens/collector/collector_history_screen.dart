import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';
import '../waste_provider/collection_detail_screen.dart';

/// Historique du Collecteur : ses collectes terminées ou annulées (voir
/// CollectionService.watchCollectorHistory) — le pendant de
/// CollectionHistoryScreen côté Fournisseur, filtré par `collectorUid` au
/// lieu de `householdUid`.
class CollectorHistoryScreen extends StatelessWidget {
  const CollectorHistoryScreen({super.key});

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
                              Text(fr ? "Historique" : "History",
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
                                      if (snap.hasError) {
                                        return Center(
                                          child: InlineErrorBanner(
                                            message: fr
                                                ? "Impossible de charger l'historique."
                                                : "Couldn't load history.",
                                          ),
                                        );
                                      }
                                      final items = snap.data ?? const [];
                                      if (items.isEmpty) {
                                        return EmptyState(
                                          icon: Icons.history_rounded,
                                          color: const Color(0xFF17A398),
                                          title: fr ? "Aucune collecte terminée" : "No completed pickup",
                                          message: fr
                                              ? "Vos collectes terminées apparaîtront ici."
                                              : "Your completed pickups will show up here.",
                                        );
                                      }
                                      return ListView.builder(
                                        padding: const EdgeInsets.only(bottom: 20, top: 8),
                                        itemCount: items.length,
                                        itemBuilder: (context, i) => _tile(context, items[i], fr),
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

  Widget _tile(BuildContext context, CollectionRequest r, bool fr) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CollectionDetailScreen(request: r)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.2),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: r.imageUrl.isEmpty
                  ? Container(
                      width: 48,
                      height: 48,
                      color: AppColors.inputFill,
                      child: Icon(r.category.icon, color: AppColors.greenMid))
                  : Image.network(r.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.category.label(fr),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                  Text(
                      r.status == RequestStatus.completed
                          ? "${(r.weightKg ?? 0).toStringAsFixed(1)} kg"
                          : r.status.label(fr),
                      style: TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                ],
              ),
            ),
            RequestStatusBadge(status: r.status, fr: fr),
          ],
        ),
      ),
    );
  }
}
