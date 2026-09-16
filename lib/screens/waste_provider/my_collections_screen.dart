import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';
import 'collection_detail_screen.dart';
import 'request_status_screen.dart';

/// "Mes collectes" : un seul écran, deux vues basculables — Collectes en
/// cours (voir CollectionService.watchActiveRequests) et Historique des
/// collectes (watchHistory) — plutôt que deux boutons séparés sur l'accueil.
class MyCollectionsScreen extends StatefulWidget {
  const MyCollectionsScreen({super.key});

  @override
  State<MyCollectionsScreen> createState() => _MyCollectionsScreenState();
}

class _MyCollectionsScreenState extends State<MyCollectionsScreen> {
  final _authService = AuthService();
  final _collectionService = CollectionService();
  bool _showActive = true;

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
                          Text(fr ? "Mes collectes" : "My collections",
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
                                child: _tab(fr ? "En cours" : "Active", _showActive,
                                    () => setState(() => _showActive = true))),
                            Expanded(
                                child: _tab(fr ? "Historique" : "History", !_showActive,
                                    () => setState(() => _showActive = false))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: uid.isEmpty
                            ? const SizedBox.shrink()
                            : StreamBuilder<List<CollectionRequest>>(
                                stream: _showActive
                                    ? _collectionService.watchActiveRequests(uid)
                                    : _collectionService.watchHistory(uid),
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
                                            ? "Impossible de charger vos collectes."
                                            : "Couldn't load your collections.",
                                        retryLabel: fr ? "Réessayer" : "Retry",
                                        onRetry: () => setState(() {}),
                                      ),
                                    );
                                  }
                                  final items = snap.data ?? const [];
                                  if (items.isEmpty) {
                                    return EmptyState(
                                      icon: _showActive
                                          ? Icons.local_shipping_outlined
                                          : Icons.history_rounded,
                                      color: _showActive
                                          ? const Color(0xFF17A398)
                                          : AppColors.greenDeep,
                                      title: _showActive
                                          ? (fr ? "Aucune collecte en cours" : "No active collection")
                                          : (fr ? "Aucun historique" : "No history yet"),
                                      message: fr
                                          ? "Postez un déchet pour lancer votre prochaine collecte."
                                          : "Post some waste to start your next collection.",
                                    );
                                  }
                                  return ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 20, top: 4),
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

  Widget _tile(BuildContext context, CollectionRequest r, bool fr) {
    final color = r.category.color;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _showActive
              ? RequestStatusScreen(requestId: r.id)
              : CollectionDetailScreen(request: r))),
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
                  ? Container(width: 48, height: 48, color: color.withOpacity(0.14), child: Icon(r.category.icon, color: color))
                  : Image.network(r.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.category.label(fr),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                  Text(_showActive ? r.quantityRange : _formatDate(r.createdAt),
                      style: TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RequestStatusBadge(status: r.status, fr: fr),
                if (!_showActive && r.status == RequestStatus.completed) ...[
                  const SizedBox(height: 4),
                  Text("+${r.pointsEarned ?? 0} pts",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
}
