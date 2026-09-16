import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../services/gemini_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';

/// Un message de la conversation avec l'Assistant IA — gardé en mémoire
/// pour la durée de l'écran seulement (pas de persistance Firestore : cette
/// conversation est un outil ponctuel, distincte des discussions
/// Fournisseur <-> Collecteur, voir ChatScreen/MessagingService).
class _AiMessage {
  final bool fromUser;
  final String text;
  const _AiMessage({required this.fromUser, required this.text});
}

/// Écran de l'Assistant IA, ouvert depuis le petit bouton flottant du
/// dashboard (voir WasteProviderShell) — conversation en direct avec l'API
/// Gemini (voir GeminiService), dans le même style de bulles que ChatScreen
/// pour rester cohérent avec le reste de l'app.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _gemini = GeminiService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_AiMessage> _messages = [];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _systemInstruction(bool fr) => '''
You are the in-app AI assistant of EcoLindk, a recyclable-waste valorisation platform.
You help users with questions about recycling, the app's supported waste categories
(plastic, paper/cardboard, glass, metal), how to post a waste collection request, points,
rewards, and the collection process. Keep answers short, friendly, and practical.
Reply in ${fr ? 'French' : 'English'}, matching the user's language.
If asked something unrelated to recycling or the app, politely redirect to those topics.
''';

  Future<void> _send() async {
    final fr = _fr(context);
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    final history = _messages
        .map((m) => GeminiChatTurn(fromUser: m.fromUser, text: m.text))
        .toList();

    setState(() {
      _messages.add(_AiMessage(fromUser: true, text: text));
      _textController.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final reply = await _gemini.chat(
        history: history,
        message: text,
        systemInstruction: _systemInstruction(fr),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_AiMessage(fromUser: false, text: reply));
        _sending = false;
      });
      _scrollToBottom();
    } on GeminiServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _errorMessage(e.code, fr);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = fr ? "Échec de la requête. Réessayez." : "Request failed. Please retry.";
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _fr(BuildContext context) => appLanguage.value == AppLanguage.fr;

  String _errorMessage(String code, bool fr) => switch (code) {
        'no-api-key' => fr
            ? "Assistant IA non configuré (clé API manquante)."
            : "AI assistant not configured (missing API key).",
        'timeout' => fr ? "La réponse a pris trop de temps." : "The response took too long.",
        'network' => fr ? "Problème de connexion réseau." : "Network connection problem.",
        _ => fr ? "Échec de la requête. Réessayez." : "Request failed. Please retry.",
      };

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
                        _header(fr),
                        Expanded(
                          child: _messages.isEmpty
                              ? EmptyState(
                                  icon: Icons.smart_toy_outlined,
                                  color: const Color(0xFF2094C4),
                                  title: fr ? "Posez votre question" : "Ask a question",
                                  message: fr
                                      ? "Recyclage, catégories, points, collectes — je suis là pour vous aider."
                                      : "Recycling, categories, points, collections — I'm here to help.",
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  itemCount: _messages.length + (_sending ? 1 : 0),
                                  itemBuilder: (context, i) {
                                    if (i >= _messages.length) return _typingBubble();
                                    return _bubble(_messages[i]);
                                  },
                                ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            child: InlineErrorBanner(
                              message: _error!,
                              retryLabel: fr ? "Réessayer" : "Retry",
                              onRetry: _send,
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

  Widget _header(bool fr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: AppColors.heading),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2094C4), Color(0xFF1668A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Text(fr ? "Assistant IA" : "AI Assistant",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.heading)),
        ],
      ),
    );
  }

  Widget _bubble(_AiMessage m) {
    final isMe = m.fromUser;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe ? AppColors.buttonGradient : null,
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
        child: Text(m.text,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: isMe ? Colors.white : AppColors.mainText)),
      ),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.line, width: 1.2),
        ),
        child: const SizedBox(
          width: 28,
          height: 14,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(color: Color(0xFF2094C4), strokeWidth: 2),
            ),
          ),
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
                hintText: fr ? "Écrivez votre question..." : "Type your question...",
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
}
