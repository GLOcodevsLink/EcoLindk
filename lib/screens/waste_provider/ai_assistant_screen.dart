import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

/// Intents clavier du composeur (voir [_composer]) : Entrée seule envoie le
/// message, Maj+Entrée insère un saut de ligne — demande explicite, comme
/// la plupart des apps de chat.
class _SendIntent extends Intent {
  const _SendIntent();
}

class _NewlineIntent extends Intent {
  const _NewlineIntent();
}

/// Écran de l'Assistant IA, ouvert depuis le petit bouton flottant du
/// dashboard (voir WasteProviderShell) ou de la carte "Assistant IA" du
/// dashboard Collecteur (voir CollectorShell, [forCollector]) — conversation en direct avec l'API
/// Gemini (voir GeminiService), dans le même style de bulles que ChatScreen
/// pour rester cohérent avec le reste de l'app.
class AiAssistantScreen extends StatefulWidget {
  /// `true` depuis le dashboard Collecteur : le cadrage du modèle couvre
  /// alors aussi le travail du collecteur (accepter/peser une collecte,
  /// commission, abonnement Premium) au lieu du seul point de vue
  /// Fournisseur.
  final bool forCollector;
  const AiAssistantScreen({super.key, this.forCollector = false});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _gemini = GeminiService();
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();

  final List<_AiMessage> _messages = [];
  bool _sending = false;
  String? _error;
  bool _speechAvailable = false;
  bool _listening = false;

  /// Index (dans [_messages]) du message actuellement lu à voix haute, ou
  /// `null` si aucun — un seul message parlé à la fois (démarrer une
  /// nouvelle lecture coupe la précédente, voir [_speak]).
  int? _speakingIndex;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    // L'initialisation demande la permission micro (Android/iOS). Un échec
    // ne bloque jamais l'assistant ; le bouton micro reste visible et
    // explique pourquoi la dictée est indisponible (avant, il disparaissait
    // sans explication).
    bool available = false;
    try {
      available = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
    } catch (e) {
      debugPrint('SpeechToText.initialize failed: $e');
    }
    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
  }

  /// Fin d'écoute (silence, délai écoulé, arrêt) : le bouton micro revient à
  /// l'état normal — avant, il restait rouge indéfiniment.
  void _onSpeechStatus(String status) {
    if ((status == 'done' || status == 'notListening') && mounted && _listening) {
      setState(() => _listening = false);
    }
  }

  /// Chaque erreur de reconnaissance est expliquée à l'utilisateur (avant,
  /// elles étaient ignorées : rien ne se passait, sans message).
  void _onSpeechError(dynamic error) {
    final msg = (error?.errorMsg as String?) ?? '';
    debugPrint('SpeechToText error: $msg');
    if (!mounted) return;
    setState(() => _listening = false);
    final fr = _fr(context);
    _snack(switch (msg) {
      'error_no_match' || 'error_speech_timeout' => fr
          ? "Je n'ai rien entendu. Parlez près du micro. Sur l'émulateur, activez d'abord le micro de l'ordinateur (⋯ > Microphone > « Virtual microphone uses host audio input »)."
          : "I didn't hear anything. Speak close to the mic. On the emulator, first enable the computer's mic (⋯ > Microphone > \"Virtual microphone uses host audio input\").",
      'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' => fr
          ? "La reconnaissance vocale a besoin d'une connexion internet."
          : "Speech recognition needs an internet connection.",
      'error_language_not_supported' || 'error_language_unavailable' => fr
          ? "Langue non installée pour la dictée : Paramètres > Système > Langues > Reconnaissance vocale, ajoutez le français."
          : "Language not installed for dictation: Settings > System > Languages > Speech recognition, add the language.",
      'error_audio' || 'error_audio_error' || 'error_permission' || 'error_insufficient_permissions' => fr
          ? "Micro inaccessible. Autorisez le micro pour EcoLindk dans les réglages du téléphone."
          : "Microphone unavailable. Allow microphone access for EcoLindk in the phone settings.",
      'error_busy' || 'error_recognizer_busy' => fr
          ? "La reconnaissance vocale est occupée. Réessayez dans un instant."
          : "Speech recognition is busy. Try again in a moment.",
      _ => fr ? "Dictée impossible ($msg). Réessayez." : "Dictation failed ($msg). Try again.",
    });
  }

  /// Langue de dictée réellement installée sur l'appareil : `fr_FR` si
  /// possible, sinon n'importe quelle variante du français (ou de
  /// l'anglais), sinon la langue du système. Demander une langue absente
  /// faisait échouer la dictée en silence.
  Future<String?> _pickSpeechLocale(bool fr) async {
    try {
      final locales = await _speech.locales();
      final ids = locales.map((l) => l.localeId).toList();
      final wanted = fr ? 'fr_FR' : 'en_US';
      final prefix = fr ? 'fr' : 'en';
      if (ids.contains(wanted)) return wanted;
      final variant = ids.where((id) => id.toLowerCase().startsWith(prefix)).firstOrNull;
      if (variant != null) return variant;
      return (await _speech.systemLocale())?.localeId;
    } catch (_) {
      return fr ? 'fr_FR' : 'en_US';
    }
  }

  /// Texte -> voix pour les réponses de l'assistant (demande explicite) —
  /// symétrique de la saisie vocale déjà en place : l'utilisateur peut
  /// écouter une réponse au lieu de la lire, utile en déplacement ou pour
  /// l'accessibilité. Purement local (moteur TTS du système), aucun appel
  /// réseau supplémentaire.
  void _initTts() {
    // Ces trois setters sont synchrones (retournent `void`, pas un
    // `Future`) — contrairement au reste de l'API FlutterTts (`speak`,
    // `stop`, `setLanguage`), jamais les préfixer de `await`.
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingIndex = null);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speakingIndex = null);
    });
    _tts.setErrorHandler((message) {
      debugPrint('FlutterTts error: $message');
      if (!mounted) return;
      setState(() => _speakingIndex = null);
      _snack(_fr(context)
          ? "Lecture vocale interrompue ($message)."
          : "Text-to-speech stopped ($message).");
    });
  }

  /// Lit à voix haute le message d'index [i] — retape dessus pour arrêter.
  /// Ne lit jamais les messages de l'utilisateur (seulement les réponses de
  /// l'assistant, voir [_bubble]).
  Future<void> _speak(int i, String text) async {
    if (_speakingIndex == i) {
      await _tts.stop();
      if (mounted) setState(() => _speakingIndex = null);
      return;
    }
    final fr = _fr(context);
    await _tts.stop();
    final language = await _pickTtsLanguage(fr);
    if (!mounted) return;
    if (language == null) {
      // Voix absente : on lit quand même avec la voix par défaut, en
      // prévenant (avant, rien ne se passait).
      _snack(fr
          ? "Voix française non installée : Paramètres > Système > Langues > Synthèse vocale > Moteur Google > Installer les données vocales."
          : "Voice not installed: Settings > System > Languages > Text-to-speech > Google engine > Install voice data.");
    } else {
      await _tts.setLanguage(language);
    }
    setState(() => _speakingIndex = i);
    // Les réponses de Gemini contiennent du Markdown (**gras**, listes) :
    // on retire ces symboles pour qu'ils ne soient pas prononcés.
    final result = await _tts.speak(text.replaceAll(RegExp(r'[*_#`>]'), ''));
    if (result != 1 && mounted) {
      setState(() => _speakingIndex = null);
      _snack(fr
          ? "Lecture vocale impossible. Vérifiez le volume et le moteur de synthèse vocale du téléphone."
          : "Text-to-speech failed. Check the volume and the phone's text-to-speech engine.");
    }
  }

  /// Voix installée pour la langue de l'app (fr-FR, sinon autre variante du
  /// français ; en-US pour l'anglais), `null` si aucune.
  Future<String?> _pickTtsLanguage(bool fr) async {
    final candidates = fr ? ['fr-FR', 'fr-CA', 'fr-BE', 'fr'] : ['en-US', 'en-GB', 'en'];
    for (final lang in candidates) {
      try {
        final ok = await _tts.isLanguageAvailable(lang);
        if (ok == true || ok == 1) return lang;
      } catch (_) {}
    }
    return null;
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _send() async {
    final fr = _fr(context);
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    if (_listening) _stopListening();
    if (_speakingIndex != null) {
      _tts.stop();
      _speakingIndex = null;
    }

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
        // Les consignes du modèle (sujets autorisés, rôle, langue) sont
        // fixées par le serveur, voir backend/src/prompts.js.
        forCollector: widget.forCollector,
        french: fr,
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

  /// Insère un saut de ligne à la position du curseur (Maj+Entrée) — geste
  /// manuel plutôt que le comportement par défaut du champ, pour que la
  /// même touche Entrée serve à la fois à valider (seule) et à aller à la
  /// ligne (avec Maj), voir [_composer].
  void _insertNewline() {
    final value = _textController.value;
    final selection = value.selection;
    final newText = value.text.replaceRange(selection.start, selection.end, '\n');
    final offset = selection.start + 1;
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  Future<void> _toggleListening() async {
    final fr = _fr(context);
    if (!_speechAvailable) {
      // Nouvelle tentative (permission accordée entre-temps, par exemple).
      await _initSpeech();
      if (!_speechAvailable) {
        _snack(fr
            ? "Dictée indisponible : autorisez le micro pour EcoLindk et vérifiez qu'un service de reconnaissance vocale (Google) est installé."
            : "Dictation unavailable: allow microphone access for EcoLindk and make sure a speech recognition service (Google) is installed.");
        return;
      }
    }
    if (_listening) {
      _stopListening();
      return;
    }
    if (_speakingIndex != null) {
      await _tts.stop();
      _speakingIndex = null;
    }
    final localeId = await _pickSpeechLocale(fr);
    if (!mounted) return;
    setState(() => _listening = true);
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _textController.text = result.recognizedWords;
            _textController.selection =
                TextSelection.collapsed(offset: _textController.text.length);
          });
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        listenOptions: stt.SpeechListenOptions(partialResults: true, cancelOnError: true),
      );
    } catch (e) {
      debugPrint('SpeechToText.listen failed: $e');
      if (mounted) setState(() => _listening = false);
      _snack(fr ? "Impossible de démarrer la dictée." : "Couldn't start dictation.");
    }
  }

  void _stopListening() {
    _speech.stop();
    if (mounted) setState(() => _listening = false);
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
        'not-configured' => fr
            ? "Assistant IA indisponible : Firebase AI Logic n'est pas encore activé pour ce projet."
            : "AI assistant unavailable: Firebase AI Logic isn't enabled for this project yet.",
        'rate-limited' => fr
            ? "Trop de questions d'affilée. Réessayez dans une minute."
            : "Too many questions in a row. Try again in a minute.",
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
                                  icon: RemixIcons.robot_fill,
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
                                    return _bubble(i, _messages[i]);
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
            icon: Icon(RemixIcons.arrow_left_line, color: AppColors.heading),
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
            child: const Icon(RemixIcons.robot_fill, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Text(fr ? "Assistant IA" : "AI Assistant",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.heading)),
        ],
      ),
    );
  }

  Widget _bubble(int i, _AiMessage m) {
    final isMe = m.fromUser;
    final speaking = _speakingIndex == i;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.text,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: isMe ? Colors.white : AppColors.mainText)),
            if (!isMe) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _speak(i, m.text),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(speaking ? RemixIcons.volume_up_fill : RemixIcons.volume_down_line,
                        size: 15, color: speaking ? const Color(0xFF2094C4) : AppColors.textGray),
                    const SizedBox(width: 4),
                    Text(
                      speaking
                          ? (_fr(context) ? "Arrêter" : "Stop")
                          : (_fr(context) ? "Écouter" : "Listen"),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: speaking ? const Color(0xFF2094C4) : AppColors.textGray),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // Entrée seule envoie, Maj+Entrée va à la ligne (demande
            // explicite) — surtout utile clavier physique/web/desktop ; sur
            // clavier tactile mobile, le bouton d'envoi reste disponible.
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): _SendIntent(),
                SingleActivator(LogicalKeyboardKey.enter, shift: true): _NewlineIntent(),
              },
              child: Actions(
                actions: {
                  _SendIntent: CallbackAction<_SendIntent>(onInvoke: (_) {
                    _send();
                    return null;
                  }),
                  _NewlineIntent: CallbackAction<_NewlineIntent>(onInvoke: (_) {
                    _insertNewline();
                    return null;
                  }),
                },
                child: TextField(
                  controller: _textController,
                  focusNode: _textFocusNode,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _listening
                        ? (fr ? "Je vous écoute..." : "Listening...")
                        : (fr ? "Écrivez votre question..." : "Type your question..."),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
          ),
          ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _listening ? Colors.redAccent : AppColors.inputFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(_listening ? RemixIcons.mic_fill : RemixIcons.mic_line,
                    color: _listening ? Colors.white : AppColors.textGray, size: 20),
              ),
            ),
          ],
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
                  : const Icon(RemixIcons.send_plane_fill, color: Colors.white, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}
