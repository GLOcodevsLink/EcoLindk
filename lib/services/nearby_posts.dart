import 'package:latlong2/latlong.dart' as ll;
import '../core/geo_config.dart';
import '../models/collection_request.dart';

/// Recherche manuelle "Autour de moi" du Collecteur : les posts à
/// [radiusKm] ou moins de sa position GPS ACTUELLE ([position]), du plus
/// proche au plus loin, avec leur distance (km).
///
/// Volontairement indépendante de ses zones de collecte (qui ne servent
/// qu'aux notifications, voir collectorsForPost) : un collecteur hors de
/// ses zones trouve quand même les posts autour de lui.
List<(CollectionRequest, double)> postsAroundPosition(
  List<CollectionRequest> posts,
  ll.LatLng position, {
  double radiusKm = GeoConfig.gpsSearchRadiusKm,
}) {
  const distance = ll.Distance();
  return posts
      .map((r) => (r, distance.as(ll.LengthUnit.Kilometer, position, ll.LatLng(r.latitude, r.longitude))))
      .where((e) => e.$2 <= radiusKm)
      .toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));
}
