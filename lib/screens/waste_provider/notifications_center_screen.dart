import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';

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

  Widget _notificationTile(AppNotification n, bool fr, String uid) {
    return InkWell(
      onTap: () {
        if (!n.read) _notificationService.markRead(uid, n.id);
      },
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
