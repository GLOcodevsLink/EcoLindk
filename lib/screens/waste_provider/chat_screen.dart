import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/conversation.dart';
import '../../services/messaging_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';

/// Écran de discussion 1-à-1 entre le Fournisseur de déchets et son
/// Collecteur (ou l'inverse) — voir MessagingService. [meUid]/[meName]
/// désignent l'utilisateur courant, [otherUid]/[otherName] son
/// interlocuteur ; les deux côtés ouvrent le même écran, chacun avec ses
/// propres "me"/"other" inversés.
class ChatScreen extends StatefulWidget {
  final String meUid;
  final String meName;
  final String otherUid;
  final String otherName;

  const ChatScreen({
    super.key,
    required this.meUid,
    required this.meName,
    required this.otherUid,
    required this.otherName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messagingService = MessagingService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  late final String _conversationId =
      _messagingService.conversationIdFor(widget.meUid, widget.otherUid);

  @override
  void initState() {
    super.initState();
    // Remet les non-lus de CET utilisateur à zéro dès l'ouverture — pas
    // besoin d'attendre qu'il fasse défiler ou réponde.
    _messagingService.markRead(_conversationId, widget.meUid);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _textController.clear();
    try {
      await _messagingService.sendMessage(
        fromUid: widget.meUid,
        fromName: widget.meName,
        toUid: widget.otherUid,
        toName: widget.otherName,
        text: text,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

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
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: _messagingService.watchMessages(_conversationId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.2));
                      }
                      if (snap.hasError) {
                        return Center(
                          child: InlineErrorBanner(
                            message: fr ? "Impossible de charger la discussion." : "Couldn't load the chat.",
                          ),
                        );
                      }
                      final messages = snap.data ?? const [];
                      if (messages.isEmpty) {
                        return EmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          color: AppColors.greenMid,
                          title: fr ? "Dites bonjour !" : "Say hello!",
                          message: fr
                              ? "Envoyez le premier message à ${widget.otherName.isEmpty ? (fr ? 'votre interlocuteur' : 'your contact') : widget.otherName}."
                              : "Send the first message to ${widget.otherName.isEmpty ? 'your contact' : widget.otherName}.",
                        );
                      }
                      // La requête trie déjà du plus récent au plus ancien —
                      // avec `reverse: true`, un ListView affiche alors le
                      // plus récent en bas, comme toute app de messagerie.
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        itemCount: messages.length,
                        itemBuilder: (context, i) => _bubble(messages[i]),
                      );
                    },
                  ),
                ),
                _composer(fr),
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

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 20, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: AppColors.heading),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.line,
            child: Icon(Icons.person, size: 18, color: AppColors.textGray),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.otherName.isEmpty ? '—' : widget.otherName,
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.heading)),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isMe = m.senderUid == widget.meUid;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe ? AppColors.buttonGradient : null,
          // Fond de bulle adapté au thème (pas de blanc en dur) — sinon le
          // texte, qui passe quasi blanc en mode sombre via
          // [AppColors.mainText], devenait illisible sur cette bulle restée
          // blanche alors que le reste de l'écran était déjà en sombre.
          color: isMe ? null : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.line, width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.text,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : AppColors.mainText)),
            const SizedBox(height: 3),
            Text(_formatTime(m.createdAt),
                style: TextStyle(
                    fontSize: 9.5,
                    color: isMe ? Colors.white70 : AppColors.textGray,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _composer(bool fr) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: fr ? "Écrire un message…" : "Write a message…",
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? d) {
    if (d == null) return '';
    return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }
}
