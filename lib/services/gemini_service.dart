import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'ai_model_settings.dart';
import 'ai_prompts.dart';

/// Un tour de conversation déjà échangé, pour renvoyer l'historique complet
/// à chaque nouvel appel (le modèle est sans état — voir [GeminiService.chat]).
class GeminiChatTurn {
  final bool fromUser;
  final String text;
  const GeminiChatTurn({required this.fromUser, required this.text});
}

/// Erreurs possibles d'un appel à l'IA — code stable consommé par les
/// écrans (jamais le message brut de l'exception).
class GeminiServiceException implements Exception {
  /// not-configured | rate-limited | network | timeout | http-error |
  /// invalid-response
  final String code;
  final String? detail;
  const GeminiServiceException(this.code, [this.detail]);

  @override
  String toString() => 'GeminiServiceException($code${detail == null ? '' : ': $detail'})';
}

/// Envoie une requête à un modèle Gemini et renvoie le texte produit.
/// Injectable pour les tests ; par défaut, Firebase AI Logic.
typedef GeminiGenerate = Future<String?> Function({
  required String model,
  Content? systemInstruction,
  required List<Content> contents,
  required GenerationConfig config,
});

/// Unique point de contact avec l'IA (texte ET image), via **Firebase AI
/// Logic** (paquet `firebase_ai`, API Gemini Developer) : aucune clé d'API
/// dans l'app ni aucun serveur à héberger, c'est le projet Firebase qui
/// sert d'identifiant. Les modèles viennent de Remote Config (voir
/// [AiModelSettings]) : le premier est essayé, puis le modèle de secours
/// s'il est surchargé ou indisponible.
class GeminiService {
  GeminiService({GeminiGenerate? generate, List<String>? models})
      : _generate = generate ?? _firebaseGenerate,
        _models = models;

  final GeminiGenerate _generate;
  final List<String>? _models;

  static const _timeout = Duration(seconds: 45);

  List<String> get _modelOrder {
    final list = _models ?? [AiModelSettings.model, AiModelSettings.fallbackModel];
    return list.where((m) => m.isNotEmpty).toSet().toList();
  }

  static Future<String?> _firebaseGenerate({
    required String model,
    Content? systemInstruction,
    required List<Content> contents,
    required GenerationConfig config,
  }) async {
    final generative = FirebaseAI.googleAI().generativeModel(
      model: model,
      systemInstruction: systemInstruction,
      generationConfig: config,
    );
    final response = await generative.generateContent(contents);
    return response.text;
  }

  /// Envoie l'historique + le nouveau message, renvoie la réponse. Les
  /// consignes (sujets autorisés, rôle, langue) viennent de [AiPrompts].
  Future<String> chat({
    required List<GeminiChatTurn> history,
    required String message,
    required bool forCollector,
    required bool french,
  }) async {
    final text = await _run(
      systemInstruction: Content.system(AiPrompts.assistant(forCollector: forCollector, french: french)),
      contents: [
        for (final t in history) t.fromUser ? Content.text(t.text) : Content.model([TextPart(t.text)]),
        Content.text(message),
      ],
      // Les jetons de réflexion du modèle comptent dans cette limite.
      config: GenerationConfig(temperature: 0.6, maxOutputTokens: 2048),
    );
    return text.trim();
  }

  /// Envoie une photo de déchet, renvoie le JSON produit par le modèle
  /// (`category`, `confidence`, `estimatedWeightKg` — voir AiClassifier).
  Future<Map<String, dynamic>> classifyWasteImage({
    required List<int> imageBytes,
    required String mimeType,
  }) async {
    final text = await _run(
      contents: [
        Content.multi([
          TextPart(AiPrompts.classify),
          InlineDataPart(mimeType, Uint8List.fromList(imageBytes)),
        ]),
      ],
      config: GenerationConfig(temperature: 0.2, maxOutputTokens: 1024, responseMimeType: 'application/json'),
    );
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Traité juste en dessous.
    }
    throw const GeminiServiceException('invalid-response');
  }

  Future<String> _run({
    Content? systemInstruction,
    required List<Content> contents,
    required GenerationConfig config,
  }) async {
    final models = _modelOrder;
    if (models.isEmpty) throw const GeminiServiceException('not-configured');
    GeminiServiceException? last;
    for (final model in models) {
      try {
        final text = await _generate(
          model: model,
          systemInstruction: systemInstruction,
          contents: contents,
          config: config,
        ).timeout(_timeout);
        if (text == null || text.trim().isEmpty) throw const GeminiServiceException('invalid-response');
        return text;
      } catch (e) {
        last = _map(e);
        // Seules les indisponibilités du modèle justifient d'essayer le
        // suivant ; une mauvaise configuration du projet échouerait pareil.
        final tryNext = last.code == 'http-error' || last.code == 'rate-limited' || last.code == 'timeout';
        debugPrint('Gemini ($model) : $e${tryNext ? ' — essai du modèle suivant' : ''}');
        if (!tryNext) throw last;
      }
    }
    throw last!;
  }

  static GeminiServiceException _map(Object e) => switch (e) {
        GeminiServiceException() => e,
        ServiceApiNotEnabled() || InvalidApiKey() =>
          GeminiServiceException('not-configured', e.toString()),
        QuotaExceeded() => GeminiServiceException('rate-limited', e.toString()),
        TimeoutException() => const GeminiServiceException('timeout'),
        SocketException() => const GeminiServiceException('network'),
        FirebaseAIException() || FirebaseAISdkException() => GeminiServiceException('http-error', e.toString()),
        _ when e.toString().contains('SocketException') || e.toString().contains('ClientException') =>
          const GeminiServiceException('network'),
        _ => GeminiServiceException('http-error', e.toString()),
      };
}
