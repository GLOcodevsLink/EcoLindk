import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';
import '../waste_provider/request_status_screen.dart';
import 'collector_map_screen.dart';

/// "Collectes à faire" du Collecteur — deux onglets :
/// - Disponibles : la carte + liste des demandes encore libres (voir
///   CollectorMapScreen), pour en accepter une nouvelle.
/// - En cours : les demandes déjà acceptées par ce collecteur, pas encore
///   terminées — chacune ouvre RequestStatusScreen pour faire avancer son
///   statut (en cours -> terminée, avec le poids).
class CollectorTasksScreen extends StatefulWidget {
  /// `true` quand affiché comme onglet du dashboard (CollectorShell, pas de
  /// flèche retour) ; `false` (défaut) quand ouvert par un push classique.
  final bool embedded;
  const CollectorTasksScreen({super.key, this.embedded = false});

  @override
  State<CollectorTasksScreen> createState() => _CollectorTasksScreenState();
}

class _CollectorTasksScreenState extends State<CollectorTasksScreen> {
  final _authService = AuthService();
  final _collectionService = CollectionService();
  bool _showAvailable = true;

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
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (!widget.embedded)
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(Icons.arrow_back, color: AppColors.heading),
                                ),
                              if (widget.embedded) const SizedBox(width: 4),
                              Text(fr ? "Collectes à faire" : "Pickups to do",
                                  style: TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
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
                                    child: _tab(fr ? "Disponibles" : "Available", _showAvailable,
                                        () => setState(() => _showAvailable = true))),
                                Expanded(
                                    child: _tab(fr ? "En cours" : "In progress", !_showAvailable,
                                        () => setState(() => _showAvailable = false))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _showAvailable
                                ? const CollectorMapScreen()
                                : _activeList(uid, fr),
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
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textGray,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _activeList(String uid, bool fr) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<CollectionRequest>>(
      stream: _collectionService.watchCollectorActiveRequests(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4));
        }
        if (snap.hasError) {
          return Center(
            child: InlineErrorBanner(
              message: fr ? "Impossible de charger vos collectes." : "Couldn't load your pickups.",
            ),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.assignment_outlined,
            color: const Color(0xFF2094C4),
            title: fr ? "Aucune collecte en cours" : "No pickup in progress",
            message: fr
                ? "Acceptez une demande depuis l'onglet Disponibles."
                : "Accept a request from the Available tab.",
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: items.length,
          itemBuilder: (context, i) => _tile(items[i], fr),
        );
      },
    );
  }

  Widget _tile(CollectionRequest r, bool fr) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RequestStatusScreen(requestId: r.id)),
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
                  Text(r.address.isEmpty ? '—' : r.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
