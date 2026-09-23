import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/env_config.dart';

/// Erreur renvoyée par [StockImgClient] — [code] vaut `not-configured`,
/// `unauthorized` (401), `forbidden` (403), `rejected` (422 : type, taille
/// ou quota), `rate-limited` (429), `network` ou `http-<status>`.
class StockImgException implements Exception {
  const StockImgException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'StockImgException($code${message == null ? '' : ': $message'})';
}

/// Client de l'API StockImg (hébergement des fichiers : images, PDF), qui
/// remplace Firebase Storage. Firestore continue de stocker les données ;
/// seule l'URL publique renvoyée par StockImg y est enregistrée.
///
/// Configuration dans `.env` (voir core/env_config.dart) :
/// `STOCKIMG_BASE_URL` et `STOCKIMG_API_KEY`.
///
/// Limites côté serveur : 5 Mo par image, 10 Mo par PDF, JPEG/PNG/WEBP/PDF
/// uniquement, 30 requêtes/minute.
class StockImgClient {
  StockImgClient({String? baseUrl, String? apiKey, http.Client? httpClient})
      : baseUrl = baseUrl ?? EnvConfig.stockImgBaseUrl,
        apiKey = apiKey ?? EnvConfig.stockImgApiKey,
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  static const _timeout = Duration(seconds: 60);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/$path');

  void _ensureConfigured() {
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      throw const StockImgException('not-configured');
    }
  }

  /// Envoie un fichier (image ou PDF) et renvoie son URL publique.
  Future<String> uploadFile(File file) async {
    _ensureConfigured();
    final request = http.MultipartRequest('POST', _uri('files'))
      ..headers.addAll(_headers)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on SocketException {
      throw const StockImgException('network');
    } on http.ClientException {
      throw const StockImgException('network');
    }

    if (response.statusCode != 201) _throwFor(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['data'] as Map<String, dynamic>)['url'] as String;
  }

  /// Liste les fichiers déjà envoyés avec cette clé, les plus récents d'abord.
  Future<List<Map<String, dynamic>>> listFiles() async {
    _ensureConfigured();
    final response = await _http.get(_uri('files'), headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) _throwFor(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// Supprime un fichier par son id.
  Future<void> deleteFile(int id) async {
    _ensureConfigured();
    final response = await _http.delete(_uri('files/$id'), headers: _headers).timeout(_timeout);
    if (response.statusCode != 204) _throwFor(response);
  }

  Never _throwFor(http.Response response) {
    String? message;
    try {
      message = (jsonDecode(response.body) as Map<String, dynamic>)['message'] as String?;
    } catch (_) {
      message = response.body;
    }
    final code = switch (response.statusCode) {
      401 => 'unauthorized',
      403 => 'forbidden',
      422 => 'rejected',
      429 => 'rate-limited',
      final s => 'http-$s',
    };
    throw StockImgException(code, message);
  }
}
