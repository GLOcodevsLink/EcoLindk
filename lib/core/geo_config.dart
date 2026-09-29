/// Réglages géographiques de l'app — une seule source, à modifier ici.
///
/// Deux mécanismes volontairement SÉPARÉS :
/// - les **zones de collecte** du Collecteur (profil) servent à cibler les
///   notifications de nouveaux posts ([zoneNotificationRadiusKm]) ;
/// - son **GPS actuel** sert à la recherche manuelle de posts autour de lui
///   ("Autour de moi" sur la carte, [gpsSearchRadiusKm]).
class GeoConfig {
  const GeoConfig._();

  /// Un Collecteur est notifié d'un nouveau post si AU MOINS UNE de ses
  /// zones de collecte en est à cette distance ou moins.
  static const double zoneNotificationRadiusKm = 5;

  /// Rayon de la recherche "Autour de moi", autour du GPS actuel.
  static const double gpsSearchRadiusKm = 10;

  /// Nombre maximal de zones de collecte par Collecteur.
  static const int maxCollectionZones = 5;
}
