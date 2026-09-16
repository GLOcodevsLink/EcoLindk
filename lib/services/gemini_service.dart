import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env_config.dart';

/// Un tour de conversation déjà échangé, pour renvoyer l'historique complet
/// à chaque nouvel appel (l'API Gemini est sans état — voir [GeminiService.chat]).
class GeminiChatTurn {
  final bool fromUser;
  final String text;
  const GeminiChatTurn({required this.fromUser, required this.text});
}

/// Erreurs possibles d'un appel à l'API Gemini — code stable consommé par
/// les écrans/services appelants (jamais le message brut de l'exception, qui
/// pourrait un jour finir par fuiter des détails techniques à l'écran).
class GeminiServiceException implements Exception {
  final String code; // no-api-key | network | timeout | http-error | invalid-response
  final String? detail;
  const GeminiServiceException(this.code, [this.detail]);

  @override
  String toString() => 'GeminiServiceException($code)';
}

/// Unique point de contact avec l'API Gemini (texte ET image) — voir
/// EnvConfig pour la clé (jamais codée en dur, jamais logguée ici même dans
/// les messages d'erreur). Isolé dans ce service pour que ni l'UI
/// (AiAssistantScreen) ni la logique métier (AiClassifier) n'aient à
/// connaître le format de requête/réponse de l'API elle-même.
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Modèle multimodal (texte + image), rapide et disponible en v1beta —
  // même modèle pour la conversation et la classification d'images pour
  // n'avoir qu'une seule intégration à maintenir.
  static const _model = 'gemini-2.5-flash';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const _timeout = Duration(seconds: 30);

  Uri get _endpoint {
    final key = EnvConfig.geminiApiKey;
    return Uri.parse('$_baseUrl/$_model:generateContent?key=$key');
  }

  /// Envoie l'historique + le nouveau message utilisateur, renvoie le texte
  /// de la réponse du modèle. [systemInstruction] cadre le rôle de
  /// l'assistant (voir AiAssistantScreen) sans jamais apparaître dans la
  /// conversation visible à l'écran.
  Future<String> chat({
    required List<GeminiChatTurn> history,
    required String message,
    required String systemInstruction,
  }) async {
    if (!EnvConfig.hasGeminiApiKey) {
      throw const GeminiServiceException('no-api-key');
    }
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': [
        ...history.map((t) => {
              'role': t.fromUser ? 'user' : 'model',
              'parts': [
                {'text': t.text}
              ],
            }),
        {
          'role': 'user',
          'parts': [
            {'text': message}
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.6,
        'maxOutputTokens': 512,
      },
    };

    final json = await _post(body);
    final text = _extractText(json);
    if (text == null || text.trim().isEmpty) {
      throw const GeminiServiceException('invalid-response');
    }
    return text.trim();
  }

  /// Envoie une photo de déchet + consigne, demande une réponse JSON stricte
  /// contenant la catégorie recyclable reconnue par EcoLindk et une
  /// estimation de quantité. Ne renvoie JAMAIS de catégorie inventée : le
  /// prompt liste explicitement les seules valeurs autorisées, et
  /// [AiClassifier] retombe sur `unsupported` si le modèle sort de ce cadre.
  Future<Map<String, dynamic>> classifyWasteImage({
    required List<int> imageBytes,
    required String mimeType,
    required String prompt,
  }) async {
    if (!EnvConfig.hasGeminiApiKey) {
      throw const GeminiServiceException('no-api-key');
    }
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(imageBytes),
              }
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 256,
        'responseMimeType': 'application/json',
      },
    };

    final json = await _post(body);
    final text = _extractText(json);
    if (text == null || text.trim().isEmpty) {
      throw const GeminiServiceException('invalid-response');
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const GeminiServiceException('invalid-response');
    } on FormatException {
      throw const GeminiServiceException('invalid-response');
    }
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const GeminiServiceException('timeout');
    } catch (_) {
      // Pas d'internet, DNS, hôte injoignable, etc. — jamais l'exception
      // brute (pourrait contenir des détails techniques) dans l'UI.
      throw const GeminiServiceException('network');
    }

    if (response.statusCode != 200) {
      throw GeminiServiceException('http-error', 'status ${response.statusCode}');
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      throw const GeminiServiceException('invalid-response');
    } on FormatException {
      throw const GeminiServiceException('invalid-response');
    }
  }

  String? _extractText(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final content = candidates.first['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) buffer.write(part['text']);
    }
    return buffer.toString();
  }
}
