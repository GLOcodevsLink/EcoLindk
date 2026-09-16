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

/// "Mes postes" : la liste brute de tout ce que le Fournisseur a posté,
/// quel que soit le statut — distinct de [MyCollectionsScreen] qui, lui,
/// organise par étape (en cours / historique). Ici, chaque post reste
/// consultable, peu importe où il en est.
class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

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
                          Text(fr ? "Mes postes" : "My posts",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.heading)),
                        ],
                      ),
                      Expanded(
                        child: uid.isEmpty
                            ? const SizedBox.shrink()
                            : StreamBuilder<List<CollectionRequest>>(
                                stream: collectionService.watchAllRequests(uid),
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
                                            ? "Impossible de charger vos postes."
                                            : "Couldn't load your posts.",
                                      ),
                                    );
                                  }
                                  final items = snap.data ?? const [];
                                  if (items.isEmpty) {
                                    return EmptyState(
                                      icon: Icons.photo_camera_outlined,
                                      color: const Color(0xFF4A6FA5),
                                      title: fr ? "Aucun poste" : "No posts yet",
                                      message: fr
                                          ? "Vos déchets postés apparaîtront ici."
                                          : "The waste you post will show up here.",
                                    );
                                  }
                                  return GridView.builder(
                                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 0.82,
                                    ),
                                    itemCount: items.length,
                                    itemBuilder: (context, i) => _postTile(context, items[i], fr),
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

  Widget _postTile(BuildContext context, CollectionRequest r, bool fr) {
    final color = r.category.color;
    final isSettled = r.status == RequestStatus.completed || r.status == RequestStatus.cancelled;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              isSettled ? CollectionDetailScreen(request: r) : RequestStatusScreen(requestId: r.id))),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  r.imageUrl.isEmpty
                      ? Container(color: color.withOpacity(0.14), child: Icon(r.category.icon, color: color, size: 30))
                      : Image.network(r.imageUrl, fit: BoxFit.cover),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: RequestStatusBadge(status: r.status, fr: fr),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.category.label(fr),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                  Text(_formatDate(r.createdAt), style: TextStyle(fontSize: 10, color: AppColors.textGray)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
}
