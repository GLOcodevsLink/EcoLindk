import 'dart:async';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Modèles Gemini utilisés par l'IA, réglables à distance depuis la console
/// Firebase (Remote Config), sans mettre l'app à jour :
/// - `gemini_model` : modèle essayé en premier ;
/// - `gemini_fallback_model` : modèle de secours s'il est surchargé ou
///   indisponible.
/// Sans connexion ou sans valeur dans la console, les valeurs par défaut
/// ci-dessous s'appliquent.
class AiModelSettings {
  const AiModelSettings._();

  static const defaultModel = 'gemini-3.8-flash';
  static const defaultFallbackModel = 'gemini-3.6-flash';

  static const _modelKey = 'gemini_model';
  static const _fallbackKey = 'gemini_fallback_model';

  static bool _ready = false;

  /// À appeler une fois au démarrage (voir main.dart). Ne bloque jamais le
  /// lancement : en cas d'échec, les valeurs par défaut restent.
  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setDefaults(const {_modelKey: defaultModel, _fallbackKey: defaultFallbackModel});
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // En développement, un changement dans la console s'applique vite ;
        // en production, une relecture par heure suffit.
        minimumFetchInterval: kDebugMode ? const Duration(minutes: 1) : const Duration(hours: 1),
      ));
      _ready = true;
      await rc.fetchAndActivate();
    } catch (e) {
      debugPrint('AiModelSettings.init: $e');
    }
  }

  static String _read(String key, String fallback) {
    if (!_ready) return fallback;
    try {
      final value = FirebaseRemoteConfig.instance.getString(key).trim();
      return value.isEmpty ? fallback : value;
    } catch (_) {
      return fallback;
    }
  }

  static String get model => _read(_modelKey, defaultModel);
  static String get fallbackModel => _read(_fallbackKey, defaultFallbackModel);
}
