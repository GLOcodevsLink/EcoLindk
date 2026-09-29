import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Un lieu proposé par la recherche (ville ou quartier).
class PlaceResult {
  final String name;
  final String city; // ville contenant le lieu ('' pour une ville elle-même)
  final String country;
  final String countryCode; // ISO alpha-2 en majuscules, ex. "CM"
  final double latitude;
  final double longitude;

  /// Emprise [ouest, sud, est, nord] quand connue (villes) — sert à limiter
  /// la recherche de quartiers à cette ville.
  final List<double>? bbox;

  const PlaceResult({
    required this.name,
    required this.city,
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    this.bbox,
  });
}

/// Erreurs de recherche : `network`, `timeout` ou `http-error`.
class PlaceSearchException implements Exception {
  final String code;
  const PlaceSearchException(this.code);

  @override
  String toString() => 'PlaceSearchException($code)';
}

/// Recherche de villes et de quartiers dans les données **OpenStreetMap**,
/// via l'API publique **Photon** (komoot) — choisie plutôt que Nominatim
/// pour la saisie au fil de la frappe ("Yaou…" → Yaoundé) : la politique
/// d'usage de Nominatim interdit l'autocomplétion, Photon est conçu pour
/// ça. L'écran appelant attend une courte pause dans la frappe avant de
/// chercher (voir ZonePickerScreen) pour rester raisonnable envers ce
/// service gratuit. Aucune clé d'API.
class PlaceSearchService {
  PlaceSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://photon.komoot.io/api/';
  static const _userAgent = 'EcoLindk/1.0 (contact@ecolindk.app)';
  static const _timeout = Duration(seconds: 12);

  /// Types OSM retenus comme "quartier" : lieux habités et subdivisions
  /// administratives d'une ville — jamais une route, une école ou une
  /// boutique qui porterait le même nom.
  static const _neighborhoodPlaceTypes = {
    'suburb', 'neighbourhood', 'quarter', 'borough', 'city_block', 'village', 'hamlet',
  };

  /// Villes dont le nom correspond à [query], limitées au pays
  /// [countryCode] (ex. "CM") s'il est fourni.
  Future<List<PlaceResult>> searchCities(String query, {String? countryCode}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final features = await _search({
      'q': q,
      'limit': '15',
      'lang': 'fr',
      'osm_tag': ['place:city', 'place:town'],
    });
    final wanted = countryCode?.toUpperCase();
    final results = <PlaceResult>[];
    final seen = <String>{};
    for (final f in features) {
      final p = f.properties;
      final cc = (p['countrycode'] as String? ?? '').toUpperCase();
      if (wanted != null && wanted.isNotEmpty && cc != wanted) continue;
      final name = p['name'] as String? ?? '';
      if (name.isEmpty || !seen.add('$name|$cc')) continue;
      results.add(PlaceResult(
        name: name,
        city: '',
        country: p['country'] as String? ?? '',
        countryCode: cc,
        latitude: f.latitude,
        longitude: f.longitude,
        bbox: _extent(p['extent']),
      ));
    }
    return results;
  }

  /// Quartiers de la ville [city] dont le nom correspond à [query].
  Future<List<PlaceResult>> searchNeighborhoods(String query, {required PlaceResult city}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final bbox = city.bbox;
    final features = await _search({
      'q': q,
      'limit': '20',
      'lang': 'fr',
      if (bbox != null) 'bbox': bbox.join(','),
      // Sans emprise connue, on privilégie les résultats proches du centre.
      if (bbox == null) ...{'lat': '${city.latitude}', 'lon': '${city.longitude}'},
    });
    final results = <PlaceResult>[];
    final seen = <String>{};
    for (final f in features) {
      final p = f.properties;
      final key = p['osm_key'] as String? ?? '';
      final value = p['osm_value'] as String? ?? '';
      final isPlace = key == 'place' && _neighborhoodPlaceTypes.contains(value);
      final isDistrict = key == 'boundary' && value == 'administrative' && p['type'] == 'district';
      if (!isPlace && !isDistrict) continue;
      final cc = (p['countrycode'] as String? ?? '').toUpperCase();
      if (city.countryCode.isNotEmpty && cc.isNotEmpty && cc != city.countryCode) continue;
      final name = p['name'] as String? ?? '';
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      results.add(PlaceResult(
        name: name,
        city: city.name,
        country: city.country,
        countryCode: city.countryCode,
        latitude: f.latitude,
        longitude: f.longitude,
      ));
    }
    return results;
  }

  Future<List<_Feature>> _search(Map<String, dynamic> params) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    http.Response response;
    try {
      response = await _client.get(uri, headers: const {'User-Agent': _userAgent}).timeout(_timeout);
    } on TimeoutException {
      throw const PlaceSearchException('timeout');
    } catch (_) {
      throw const PlaceSearchException('network');
    }
    if (response.statusCode != 200) throw const PlaceSearchException('http-error');
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (json['features'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_Feature.fromJson)
          .whereType<_Feature>()
          .toList();
    } catch (_) {
      throw const PlaceSearchException('http-error');
    }
  }

  /// Photon renvoie l'emprise en [ouest, nord, est, sud] ; on la remet en
  /// [ouest, sud, est, nord], l'ordre attendu par son paramètre `bbox`.
  static List<double>? _extent(Object? raw) {
    if (raw is! List || raw.length != 4) return null;
    final v = raw.map((e) => (e as num).toDouble()).toList();
    return [v[0], v[3], v[2], v[1]];
  }
}

class _Feature {
  final Map<String, dynamic> properties;
  final double latitude;
  final double longitude;
  const _Feature(this.properties, this.latitude, this.longitude);

  static _Feature? fromJson(Map<String, dynamic> json) {
    final coords = (json['geometry'] as Map?)?['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    return _Feature(
      Map<String, dynamic>.from(json['properties'] as Map? ?? const {}),
      (coords[1] as num).toDouble(),
      (coords[0] as num).toDouble(),
    );
  }
}
