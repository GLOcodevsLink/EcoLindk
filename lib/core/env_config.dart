import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Accès centralisé aux variables d'environnement (fichier `.env` à la
/// racine du projet, jamais commité — voir .gitignore). Aucune clé d'API ne
/// doit jamais être écrite en dur dans un fichier Dart ni stockée dans
/// Firestore/Firebase Auth : elle vit uniquement dans `.env`, chargé au
/// démarrage par [loadEnv] (voir main.dart) et lu ici.
class EnvConfig {
  const EnvConfig._();

  /// À appeler une seule fois, avant `runApp` (voir main.dart). Si `.env`
  /// est absent (ex. tout juste cloné, avant que le développeur n'y ait mis
  /// sa propre clé), l'app démarre quand même — [geminiApiKey] renverra
  /// simplement une chaîne vide plutôt que de faire planter le lancement.
  static Future<void> loadEnv() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Fichier absent ou illisible : les getters ci-dessous renverront ''
      // (voir leur repli sur dotenv.env qui restera vide dans ce cas).
    }
  }

  /// Clé Gemini renseignée par le développeur dans `.env`
  /// (`GEMINI_API_KEY=...`) — vide si non configurée, jamais une valeur
  /// codée en dur ici.
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// `true` une fois qu'une vraie clé a été renseignée (pas le placeholder
  /// du `.env` d'exemple, pas une valeur vide) — à vérifier avant tout appel
  /// réel à l'API Gemini.
  static bool get hasGeminiApiKey =>
      geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';
}
