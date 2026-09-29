/// Une zone de collecte d'un Collecteur : pays → ville → quartier, choisis
/// parmi les résultats OpenStreetMap (voir PlaceSearchService), avec les
/// coordonnées du quartier quand elles sont connues.
///
/// Stockée dans `users/{uid}.collectionZones` (liste de maps, 5 au plus —
/// voir GeoConfig.maxCollectionZones) et recopiée dans
/// `collectorLocations/{uid}.zones` pour le ciblage des notifications (voir
/// CollectorZoneService).
class CollectionZone {
  final String country;
  final String countryCode; // ISO 3166-1 alpha-2, ex. "CM" ; '' si inconnu
  final String city;
  final String neighborhood;
  final double? latitude;
  final double? longitude;

  const CollectionZone({
    required this.country,
    required this.countryCode,
    required this.city,
    required this.neighborhood,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  /// "Cameroun → Yaoundé → Bastos" (parties vides omises).
  String get label => [country, city, neighborhood].where((p) => p.trim().isNotEmpty).join(' → ');

  /// Clé de comparaison insensible à la casse et aux accents : deux zones de
  /// même clé sont un doublon ("Éssos" = "essos").
  String get key => '${normalize(countryCode.isEmpty ? country : countryCode)}|${normalize(city)}|${normalize(neighborhood)}';

  /// Même quartier dans la même ville (utilisé en complément de la
  /// distance pour le ciblage des notifications).
  bool sameNeighborhoodAs(String? otherCity, String? otherNeighborhood) {
    if (otherNeighborhood == null || otherNeighborhood.trim().isEmpty) return false;
    if (normalize(neighborhood) != normalize(otherNeighborhood)) return false;
    // Ville inconnue d'un côté (ancienne zone) : le nom du quartier suffit.
    if (city.trim().isEmpty || otherCity == null || otherCity.trim().isEmpty) return true;
    return normalize(city) == normalize(otherCity);
  }

  Map<String, dynamic> toMap() => {
        'country': country,
        'countryCode': countryCode,
        'city': city,
        'neighborhood': neighborhood,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory CollectionZone.fromMap(Map<String, dynamic> m) => CollectionZone(
        country: (m['country'] as String?) ?? '',
        countryCode: (m['countryCode'] as String?) ?? '',
        city: (m['city'] as String?) ?? '',
        neighborhood: (m['neighborhood'] as String?) ?? '',
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
      );

  /// Zones d'un Collecteur à partir de sa fiche `users/{uid}`. Compatibilité
  /// avec l'ancien champ texte unique `collectionZone` (ex. "Mendong
  /// Yaoundé") : relu comme une seule zone, avec le point géocodé de
  /// `collectorLocations` si [legacyLatitude]/[legacyLongitude] sont
  /// fournis. Rien n'est supprimé de la fiche.
  static List<CollectionZone> fromUserData(Map<String, dynamic>? data,
      {double? legacyLatitude, double? legacyLongitude}) {
    if (data == null) return const [];
    final list = data['collectionZones'];
    if (list is List && list.isNotEmpty) {
      return list.whereType<Map>().map((m) => CollectionZone.fromMap(Map<String, dynamic>.from(m))).toList();
    }
    final legacy = (data['collectionZone'] as String?)?.trim() ?? '';
    if (legacy.isEmpty) return const [];
    return [
      CollectionZone(
        country: '',
        countryCode: '',
        city: '',
        neighborhood: legacy,
        latitude: legacyLatitude,
        longitude: legacyLongitude,
      ),
    ];
  }

  static String normalize(String s) {
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u',
      'ü': 'u', 'ú': 'u', 'ç': 'c', 'ñ': 'n',
    };
    final lower = s.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(accents[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  @override
  bool operator ==(Object other) => other is CollectionZone && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
