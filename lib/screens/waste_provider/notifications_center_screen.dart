import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';
import '../collector/collector_collection_screen.dart';
import '../collector/collector_request_preview_screen.dart';
import 'request_status_screen.dart';

/// Centre de notifications (voir NotificationService pour ce qui les
/// déclenche — toujours un événement réel, jamais générées "pour faire
/// joli"). [embedded] : `true` quand affiché comme onglet du dashboard
/// (WasteProviderShell, pas de flèche retour) ; `false` quand ouvert par un
/// push classique (garde la flèche retour).
class NotificationsCenterScreen extends StatefulWidget {
  final bool embedded;
  const NotificationsCenterScreen({super.key, this.embedded = false});

  @override
  State<NotificationsCenterScreen> createState() => _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  final _authService = AuthService();
  final _notificationService = NotificationService();

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
                          if (!widget.embedded)
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(Icons.arrow_back, color: AppColors.heading),
                            ),
                          Expanded(
                            child: Text(fr ? "Notifications" : "Notifications",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.heading)),
                          ),
                          if (uid.isNotEmpty)
                            TextButton(
                              onPressed: () => _notificationService.markAllRead(uid),
                              child: Text(fr ? "Tout marquer lu" : "Mark all read",
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: uid.isEmpty
                            ? const SizedBox.shrink()
                            : StreamBuilder<List<AppNotification>>(
                                stream: _notificationService.watch(uid),
                                builder: (context, snap) {
                                  if (snap.connectionState == ConnectionState.waiting) {
                                    return const Center(
                                        child: CircularProgressIndicator(
                                            color: AppColors.greenMid, strokeWidth: 2.2));
                                  }
                                  if (snap.hasError) {
                                    return Center(
                                      child: InlineErrorBanner(
                                        message: fr
                                            ? "Impossible de charger les notifications."
                                            : "Couldn't load notifications.",
                                        retryLabel: fr ? "Réessayer" : "Retry",
                                        onRetry: () => setState(() {}),
                                      ),
                                    );
                                  }
                                  final items = snap.data ?? const [];
                                  if (items.isEmpty) {
                                    return EmptyState(
                                      icon: Icons.notifications_none_rounded,
                                      color: const Color(0xFFB07E00),
                                      title: fr ? "Aucune notification" : "No notifications",
                                      message: fr
                                          ? "Vous serez averti dès qu'il se passe quelque chose."
                                          : "You'll be notified as soon as something happens.",
                                    );
                                  }
                                  return ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    itemCount: items.length,
                                    itemBuilder: (context, i) {
                                      final n = items[i];
                                      return _notificationTile(n, fr, uid);
                                    },
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

  /// Ouvre ce dont parle la notification :
  /// - nouveau post proche (Collecteur) : la fiche du post, pour l'accepter ;
  /// - collecte en cours dont on est le collecteur : son écran Collecte ;
  /// - sinon : le suivi de la demande (partagé par les deux rôles).
  Future<void> _open(AppNotification n, bool fr, String uid) async {
    if (!n.read) _notificationService.markRead(uid, n.id);
    final id = n.relatedRequestId;
    if (id == null) return;

    CollectionRequest? request;
    try {
      request = await CollectionService().watchRequest(id).first;
    } catch (_) {
      request = null;
    }
    if (!mounted) return;
    void snack(String fr0, String en) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(fr ? fr0 : en)));
    if (request == null) {
      snack("Cette demande n'est plus disponible.", "This request is no longer available.");
      return;
    }

    final Widget screen;
    if (n.type == NotificationType.newNearbyPost && request.collectorUid != uid) {
      if (request.status != RequestStatus.pending) {
        snack("Cette collecte a déjà été prise par un autre collecteur ou annulée.",
            "This pickup was already taken by another collector or cancelled.");
        return;
      }
      screen = CollectorRequestPreviewScreen(request: request);
    } else if (request.collectorUid == uid &&
        (request.status == RequestStatus.accepted || request.status == RequestStatus.inProgress)) {
      screen = CollectorCollectionScreen(initialRequestId: request.id);
    } else {
      screen = RequestStatusScreen(requestId: request.id);
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _notificationTile(AppNotification n, bool fr, String uid) {
    return InkWell(
      onTap: () => _open(n, fr, uid),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.read ? AppColors.card : AppColors.greenBright.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: n.read ? AppColors.line : AppColors.greenBright.withOpacity(0.35),
              width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BoxLogo(n.type.icon, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                  const SizedBox(height: 2),
                  Text(n.body,
                      style: TextStyle(fontSize: 11.5, color: AppColors.textGray, height: 1.3)),
                  const SizedBox(height: 4),
                  Text(_relativeTime(n.createdAt, fr),
                      style: TextStyle(fontSize: 10, color: AppColors.textGray)),
                ],
              ),
            ),
            if (!n.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: AppColors.greenMid, shape: BoxShape.circle),
              ),
            // Montre que la notification s'ouvre (post ou collecte liés).
            if (n.relatedRequestId != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.textGray, size: 22),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt, bool fr) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return fr ? "À l'instant" : "Just now";
    if (diff.inMinutes < 60) return fr ? "Il y a ${diff.inMinutes} min" : "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return fr ? "Il y a ${diff.inHours} h" : "${diff.inHours}h ago";
    return fr ? "Il y a ${diff.inDays} j" : "${diff.inDays}d ago";
  }
}
