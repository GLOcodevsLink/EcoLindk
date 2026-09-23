import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Résultat d'un géocodage réussi — une seule adresse retenue (la plus
/// pertinente selon Nominatim), jamais une liste de candidats à choisir :
/// l'utilisateur a déjà tapé une adresse précise, on ne lui redemande pas.
class GeocodeResult {
  final double latitude;
  final double longitude;

  /// Adresse normalisée telle que renvoyée par Nominatim — utile pour
  /// confirmer visuellement à l'utilisateur ce qui a été compris, sans
  /// changer l'adresse qu'il a tapée (celle-ci reste la valeur enregistrée).
  final String displayName;

  const GeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

/// Erreurs possibles d'un géocodage — code stable consommé par l'UI (jamais
/// le message brut de l'exception, voir la même convention que
/// [GeminiServiceException]).
class GeocodingException implements Exception {
  final String code; // empty-address | not-found | network | timeout | http-error
  const GeocodingException(this.code);

  @override
  String toString() => 'GeocodingException($code)';
}

/// Géocodage d'adresse texte -> coordonnées, via l'API publique Nominatim
/// (OpenStreetMap) — voir PostWasteScreen : appelé UNE SEULE FOIS, quand
/// l'utilisateur tape "Localiser cette adresse", jamais à chaque frappe.
///
/// Nominatim impose un `User-Agent` identifiable pour toute requête (sa
/// politique d'usage interdit les requêtes anonymes/génériques) — voir
/// https://operations.osmfoundation.org/policies/nominatim/.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';
  static const _userAgent = 'EcoLindk/1.0 (contact@ecolindk.app)';
  static const _timeout = Duration(seconds: 15);

  Future<GeocodeResult> geocode(String address) async {
    final query = address.trim();
    if (query.isEmpty) throw const GeocodingException('empty-address');

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '1',
      // Limite la recherche au Cameroun : sans ça, un nom de quartier
      // ambigu ("Akwa", "Bonamoussadi"…) peut renvoyer un lieu à l'étranger
      // (ex. aux États-Unis), le premier résultat mondial étant retenu.
      'countrycodes': 'cm',
    });

    http.Response response;
    try {
      response = await _client.get(uri, headers: const {
        'User-Agent': _userAgent,
        'Accept-Language': 'fr',
      }).timeout(_timeout);
    } on TimeoutException {
      throw const GeocodingException('timeout');
    } catch (_) {
      throw const GeocodingException('network');
    }

    if (response.statusCode != 200) {
      throw const GeocodingException('http-error');
    }

    List<dynamic> results;
    try {
      results = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    } catch (_) {
      throw const GeocodingException('http-error');
    }

    if (results.isEmpty) throw const GeocodingException('not-found');

    final first = results.first as Map<String, dynamic>;
    final lat = double.tryParse(first['lat'] as String? ?? '');
    final lon = double.tryParse(first['lon'] as String? ?? '');
    if (lat == null || lon == null) throw const GeocodingException('not-found');

    return GeocodeResult(
      latitude: lat,
      longitude: lon,
      displayName: first['display_name'] as String? ?? query,
    );
  }
}
