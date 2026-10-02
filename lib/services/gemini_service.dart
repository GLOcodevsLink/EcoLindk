import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../ai_firebase_options.dart';
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

/// Unique point de contact avec l'IA (texte ET image). Deux chemins :
/// - clé `GEMINI_API_KEY` fournie au build (`.env` +
///   `flutter run --dart-define-from-file=.env`) : appel direct à l'API
///   Gemini avec cette clé — nécessaire tant que Google refuse l'accès à
///   Gemini au projet Firebase `ecolindk` ("Your project has been denied
///   access"). La clé est alors dans l'app : la restreindre à l'API
///   "Generative Language" dans Google Cloud Console ;
/// - sinon **Firebase AI Logic** (paquet `firebase_ai`) : aucune clé dans
///   l'app, c'est le projet Firebase qui sert d'identifiant.
/// Les modèles viennent de Remote Config (voir [AiModelSettings]) : le
/// premier est essayé, puis le modèle de secours s'il est surchargé ou
/// indisponible.
class GeminiService {
  GeminiService({GeminiGenerate? generate, List<String>? models})
      : _generate = generate ?? (_apiKey.isNotEmpty ? _restGenerate : _firebaseGenerate),
        _models = models;

  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  final GeminiGenerate _generate;
  final List<String>? _models;

  static const _timeout = Duration(seconds: 45);

  List<String> get _modelOrder {
    final list = _models ?? [AiModelSettings.model, AiModelSettings.fallbackModel];
    return list.where((m) => m.isNotEmpty).toSet().toList();
  }

  /// Projet Firebase de l'IA : le projet principal, ou celui défini dans
  /// [aiFirebaseOptions] (initialisé une seule fois, sous le nom "ai").
  static Future<FirebaseApp> _aiApp() async {
    final options = aiFirebaseOptions;
    if (options == null) return Firebase.app();
    try {
      return Firebase.app('ai');
    } on FirebaseException {
      return Firebase.initializeApp(name: 'ai', options: options);
    }
  }

  static Future<String?> _firebaseGenerate({
    required String model,
    Content? systemInstruction,
    required List<Content> contents,
    required GenerationConfig config,
  }) async {
    final generative = FirebaseAI.googleAI(app: await _aiApp()).generativeModel(
      model: model,
      systemInstruction: systemInstruction,
      generationConfig: config,
    );
    final response = await generative.generateContent(contents);
    return response.text;
  }

  /// Appel direct à l'API Gemini avec [_apiKey] — même corps JSON que
  /// Firebase AI Logic (sérialisation de `firebase_ai`), seule l'adresse et
  /// l'identification changent.
  static Future<String?> _restGenerate({
    required String model,
    Content? systemInstruction,
    required List<Content> contents,
    required GenerationConfig config,
  }) =>
      restGenerate(
        client: http.Client(),
        apiKey: _apiKey,
        model: model,
        systemInstruction: systemInstruction,
        contents: contents,
        config: config,
      );

  @visibleForTesting
  static Future<String?> restGenerate({
    required http.Client client,
    required String apiKey,
    required String model,
    Content? systemInstruction,
    required List<Content> contents,
    required GenerationConfig config,
  }) async {
    final body = <String, Object?>{
      'contents': contents.map((c) => c.toJson()).toList(),
      'generationConfig': config.toJson(),
      // Le rôle "system" de Content.system n'a pas cours ici : seules
      // les parties comptent.
      if (systemInstruction != null)
        'systemInstruction': {'parts': (systemInstruction.toJson()['parts'])},
    };
    try {
      final res = await client.post(
        Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$model:generateContent'),
        headers: {'x-goog-api-key': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 429) throw GeminiServiceException('rate-limited', res.body);
      if (res.statusCode == 400 && res.body.contains('API_KEY_INVALID') || res.statusCode == 403) {
        throw GeminiServiceException('not-configured', res.body);
      }
      if (res.statusCode != 200) {
        throw GeminiServiceException('http-error', 'HTTP ${res.statusCode} ${res.body}');
      }
      return textOf(res.body);
    } finally {
      client.close();
    }
  }

  /// Texte de la première réponse (hors parties de "réflexion" du modèle).
  @visibleForTesting
  static String? textOf(String body) {
    final json = jsonDecode(body);
    final candidates = json is Map ? json['candidates'] : null;
    if (candidates is! List || candidates.isEmpty) return null;
    final content = (candidates.first as Map?)?['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return null;
    final text = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true && p['text'] is String)
        .map((p) => p['text'] as String)
        .join();
    return text.isEmpty ? null : text;
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
