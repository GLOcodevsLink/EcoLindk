import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/conversation.dart';
import '../../services/auth_service.dart';
import '../../services/messaging_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';
import 'chat_screen.dart';

/// Onglet "Messages" de la barre de navigation — volontairement DISTINCT du
/// centre de notifications (voir NotificationsCenterScreen, ouvert depuis la
/// cloche du dashboard) : les deux ne doivent jamais pointer vers le même
/// écran. Liste des conversations avec les collecteurs (voir
/// MessagingService) — une conversation existe dès qu'un des deux côtés a
/// envoyé au moins un message (typiquement depuis "Votre collecteur" sur
/// RequestStatusScreen, une fois un collecteur assigné).
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final messagingService = MessagingService();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(fr ? "Messages" : "Messages",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.heading)),
                    ),
                    Expanded(
                      child: uid.isEmpty
                          ? const SizedBox.shrink()
                          : StreamBuilder<List<ConversationSummary>>(
                              stream: messagingService.watchConversations(uid),
                              builder: (context, snap) {
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                      child:
                                          CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.2));
                                }
                                if (snap.hasError) {
                                  return Center(
                                    child: InlineErrorBanner(
                                      message: fr
                                          ? "Impossible de charger vos messages."
                                          : "Couldn't load your messages.",
                                    ),
                                  );
                                }
                                final conversations = snap.data ?? const [];
                                if (conversations.isEmpty) {
                                  return EmptyState(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    color: const Color(0xFF7C5CBF),
                                    title: fr ? "Aucun message" : "No messages yet",
                                    message: fr
                                        ? "Vos discussions avec un collecteur apparaîtront ici, une fois une collecte acceptée."
                                        : "Your chats with a collector will show up here, once a collection is accepted.",
                                  );
                                }
                                return ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                  itemCount: conversations.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) => _conversationTile(
                                      context, conversations[i], uid, authService, fr),
                                );
                              },
                            ),
                    ),
                  ],
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

  Widget _conversationTile(BuildContext context, ConversationSummary c, String uid,
      AuthService authService, bool fr) {
    final hasUnread = c.unreadCount > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        // Le nom "de soi" vient de sa propre fiche (jamais périmé, au cas où
        // il a changé depuis la création de la conversation) — celui de
        // l'autre participant reste celui déjà stocké dans la conversation.
        final doc = await authService.fetchUserDocument(uid);
        final myName = (doc.data()?['fullName'] as String?) ?? '';
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            meUid: uid,
            meName: myName,
            otherUid: c.otherUid,
            otherName: c.otherName,
          ),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Fond de carte adapté au thème (pas de blanc en dur, demande
          // explicite : visible aussi en mode sombre).
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasUnread ? AppColors.greenMid.withOpacity(0.4) : AppColors.line, width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.line,
              child: Icon(Icons.person, color: AppColors.textGray),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.otherName.isEmpty ? '—' : c.otherName,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainText)),
                  const SizedBox(height: 2),
                  Text(c.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? AppColors.mainText : AppColors.textGray,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatWhen(c.lastMessageAt),
                    style: TextStyle(fontSize: 10, color: AppColors.textGray, fontWeight: FontWeight.w600)),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: const BoxDecoration(color: AppColors.greenMid, shape: BoxShape.circle),
                    child: Text("${c.unreadCount}",
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatWhen(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    }
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";
  }
}
