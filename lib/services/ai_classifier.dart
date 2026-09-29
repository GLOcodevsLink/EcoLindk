import 'dart:io';
import '../models/collection_request.dart';
import 'gemini_service.dart';

/// Codes gérés explicitement par [PostWasteScreen] : pas d'image, image
/// invalide, échec de classification, déchet non supporté, échec réseau,
/// IA non activée dans le projet Firebase (`not-configured`).
class AiClassificationException implements Exception {
  final String code;
  const AiClassificationException(this.code);
}

class AiClassificationResult {
  final WasteCategory category;
  final double confidence; // 0..1
  /// Estimation du poids en kg renvoyée par l'IA — `null` si le modèle n'a
  /// pas pu estimer (photo trop cadrée, quantité peu claire). [PostWasteScreen]
  /// ne propose plus de paliers fixes (demande explicite : saisie libre,
  /// approximative ou exacte) — cette estimation ne fait donc plus que
  /// pré-remplir le champ, jamais un choix parmi une liste fermée.
  final double? estimatedWeightKg;
  const AiClassificationResult({
    required this.category,
    required this.confidence,
    this.estimatedWeightKg,
  });
}

/// Analyse IA réelle d'une photo de déchet via Gemini (Firebase AI Logic,
/// voir GeminiService) — jamais une vérité : l'utilisateur confirme ou corrige
/// toujours la catégorie/quantité suggérée avant de continuer (voir
/// PostWasteScreen). Ne renvoie jamais une catégorie inventée : le modèle
/// doit choisir parmi les [WasteCategory] existants de l'app, sous peine de
/// [AiClassificationException] `unsupported`.
class AiClassifier {
  const AiClassifier._();

  static Future<AiClassificationResult> classify(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) {
      throw const AiClassificationException('no-image');
    }

    final file = File(imagePath);
    List<int> bytes;
    try {
      bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw const AiClassificationException('invalid-image');
    } on AiClassificationException {
      rethrow;
    } catch (_) {
      throw const AiClassificationException('invalid-image');
    }

    return classifyBytes(bytes, _mimeTypeFor(imagePath));
  }

  /// Même analyse, à partir d'une image déjà en mémoire — typiquement la
  /// version compressée préparée dès le choix de la photo (voir
  /// PostWasteScreen) : quelques centaines de Ko à envoyer au lieu de
  /// plusieurs Mo, donc une analyse bien plus rapide sur réseau mobile.
  static Future<AiClassificationResult> classifyBytes(List<int> bytes, String mimeType) async {
    if (bytes.isEmpty) throw const AiClassificationException('invalid-image');
    Map<String, dynamic> json;
    try {
      json = await GeminiService().classifyWasteImage(
        imageBytes: bytes,
        mimeType: mimeType,
      );
    } on GeminiServiceException catch (e) {
      throw AiClassificationException(_mapServiceError(e.code));
    }

    final categoryName = json['category'] as String?;
    if (categoryName == null || categoryName == 'unsupported') {
      throw const AiClassificationException('unsupported');
    }
    final matchedCategory = WasteCategory.values
        .where((c) => c.name == categoryName)
        .cast<WasteCategory?>()
        .firstWhere((c) => c != null, orElse: () => null);
    if (matchedCategory == null) {
      throw const AiClassificationException('unsupported');
    }

    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;
    final weight = (json['estimatedWeightKg'] as num?)?.toDouble();

    return AiClassificationResult(
      category: matchedCategory,
      confidence: confidence.clamp(0.0, 1.0),
      estimatedWeightKg: (weight == null || weight <= 0) ? null : weight,
    );
  }

  static String _mapServiceError(String code) => switch (code) {
        'network' => 'network',
        'timeout' => 'network',
        'not-configured' => 'not-configured',
        _ => 'failed',
      };

  static String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
