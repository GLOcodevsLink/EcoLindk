import 'package:latlong2/latlong.dart' as ll;
import '../core/geo_config.dart';
import '../models/collection_zone.dart';

/// Un Collecteur à notifier pour un nouveau post, avec la zone la plus
/// proche qui l'a rendu éligible.
class ZoneMatch {
  final String collectorUid;

  /// Distance (km) entre le post et la zone la plus proche, `null` si le
  /// collecteur n'est éligible que par le nom du quartier.
  final double? distanceKm;
  final String zoneName;

  const ZoneMatch({required this.collectorUid, required this.distanceKm, required this.zoneName});
}

/// Collecteurs à notifier pour un post situé en ([latitude], [longitude]),
/// dans le quartier [neighborhood] de la ville [city] (si connus), à partir
/// des documents `collectorLocations/{uid}` ([collectorLocations] : uid →
/// données).
///
/// Un collecteur est éligible si AU MOINS UNE de ses zones :
/// - est à [radiusKm] ou moins du post (distance réelle, quand la zone a des
///   coordonnées), ou
/// - porte le même quartier dans la même ville.
///
/// Il n'apparaît qu'UNE fois dans le résultat, même si plusieurs de ses
/// zones correspondent (une seule notification par post). Les anciens
/// documents (un seul point `latitude`/`longitude`, sans `zones`) restent
/// pris en compte.
List<ZoneMatch> collectorsForPost({
  required double latitude,
  required double longitude,
  String? city,
  String? neighborhood,
  required Map<String, Map<String, dynamic>> collectorLocations,
  double radiusKm = GeoConfig.zoneNotificationRadiusKm,
}) {
  const distance = ll.Distance();
  final post = ll.LatLng(latitude, longitude);
  final matches = <ZoneMatch>[];

  collectorLocations.forEach((uid, data) {
    final zones = _zonesOf(data);
    double? bestKm;
    String bestName = '';
    var nameMatch = false;
    String nameMatchZone = '';

    for (final z in zones) {
      if (z.hasCoordinates) {
        final km = distance.as(ll.LengthUnit.Kilometer, post, ll.LatLng(z.latitude!, z.longitude!));
        if (bestKm == null || km < bestKm) {
          bestKm = km;
          bestName = z.neighborhood;
        }
      }
      if (!nameMatch && z.sameNeighborhoodAs(city, neighborhood)) {
        nameMatch = true;
        nameMatchZone = z.neighborhood;
      }
    }

    final withinRadius = bestKm != null && bestKm <= radiusKm;
    if (withinRadius) {
      matches.add(ZoneMatch(collectorUid: uid, distanceKm: bestKm, zoneName: bestName));
    } else if (nameMatch) {
      matches.add(ZoneMatch(collectorUid: uid, distanceKm: null, zoneName: nameMatchZone));
    }
  });
  return matches;
}

List<CollectionZone> _zonesOf(Map<String, dynamic> data) {
  final zones = data['zones'];
  if (zones is List) {
    return zones.whereType<Map>().map((m) => CollectionZone.fromMap(Map<String, dynamic>.from(m))).toList();
  }
  // Ancien format : un seul point géocodé.
  final lat = (data['latitude'] as num?)?.toDouble();
  final lng = (data['longitude'] as num?)?.toDouble();
  if (lat == null || lng == null) return const [];
  return [CollectionZone(country: '', countryCode: '', city: '', neighborhood: '', latitude: lat, longitude: lng)];
}
