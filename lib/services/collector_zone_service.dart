import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/geo_config.dart';
import '../models/collection_zone.dart';

/// Erreur de modification des zones : `max-reached` (déjà
/// [GeoConfig.maxCollectionZones] zones) ou `duplicate` (zone déjà
/// enregistrée).
class CollectionZoneException implements Exception {
  final String code;
  const CollectionZoneException(this.code);

  @override
  String toString() => 'CollectionZoneException($code)';
}

/// Zones de collecte d'un Collecteur, enregistrées à deux endroits dans le
/// MÊME lot d'écriture (jamais l'un sans l'autre) :
/// - `users/{uid}.collectionZones` : la liste complète (profil), lisible
///   par le seul collecteur (voir firestore.rules) ;
/// - `collectorLocations/{uid}.zones` : copie minimale (coordonnées, ville,
///   quartier), lisible par tout utilisateur connecté — c'est elle que lit
///   l'appareil du Fournisseur qui publie un post pour savoir quels
///   collecteurs notifier (voir CollectionService._notifyZoneCollectors).
///
/// Une modification s'applique donc dès le post suivant, sans rien recréer.
/// L'ancien champ texte unique `collectionZone` n'est jamais supprimé ; il
/// est relu comme une zone tant que la nouvelle liste n'existe pas.
class CollectorZoneService {
  CollectorZoneService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _firestore.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _location(String uid) =>
      _firestore.collection('collectorLocations').doc(uid);

  /// Zones actuelles (avec compatibilité de l'ancien champ unique).
  Future<List<CollectionZone>> load(String uid) async {
    final user = await _user(uid).get();
    final data = user.data();
    if (data?['collectionZones'] is List) return CollectionZone.fromUserData(data);
    // Ancienne zone : on récupère aussi son point géocodé, s'il existe.
    final location = (await _location(uid).get()).data();
    return CollectionZone.fromUserData(
      data,
      legacyLatitude: (location?['latitude'] as num?)?.toDouble(),
      legacyLongitude: (location?['longitude'] as num?)?.toDouble(),
    );
  }

  /// Ajoute [zone] aux zones existantes et enregistre. Lève
  /// [CollectionZoneException].
  Future<List<CollectionZone>> add(String uid, CollectionZone zone) async {
    final zones = await load(uid);
    return save(uid, [...zones, zone]);
  }

  /// Remplace la zone d'index [index] par [zone].
  Future<List<CollectionZone>> replace(String uid, int index, CollectionZone zone) async {
    final zones = [...await load(uid)];
    if (index < 0 || index >= zones.length) throw RangeError.index(index, zones);
    zones[index] = zone;
    return save(uid, zones);
  }

  Future<List<CollectionZone>> remove(String uid, int index) async {
    final zones = [...await load(uid)];
    if (index < 0 || index >= zones.length) throw RangeError.index(index, zones);
    zones.removeAt(index);
    return save(uid, zones);
  }

  /// Vérifie la liste (5 au plus, sans doublon) puis l'enregistre aux deux
  /// endroits dans un même lot.
  Future<List<CollectionZone>> save(String uid, List<CollectionZone> zones) async {
    validate(zones);
    final batch = _firestore.batch();
    batch.update(_user(uid), {'collectionZones': zones.map((z) => z.toMap()).toList()});
    batch.set(_location(uid), locationIndexFor(zones), SetOptions(merge: true));
    await batch.commit();
    return zones;
  }

  /// Règles de la liste, aussi utilisées par l'UI avant d'enregistrer.
  static void validate(List<CollectionZone> zones) {
    if (zones.length > GeoConfig.maxCollectionZones) {
      throw const CollectionZoneException('max-reached');
    }
    if (zones.map((z) => z.key).toSet().length != zones.length) {
      throw const CollectionZoneException('duplicate');
    }
  }

  /// Contenu de `collectorLocations/{uid}` pour ces zones. Le premier point
  /// connu reste aussi dans `latitude`/`longitude` (ancien format), pour les
  /// versions de l'app qui ne lisent pas encore `zones`.
  static Map<String, dynamic> locationIndexFor(List<CollectionZone> zones) {
    final withCoords = zones.where((z) => z.hasCoordinates).toList();
    return {
      'zones': zones
          .map((z) => {
                'city': z.city,
                'neighborhood': z.neighborhood,
                'latitude': z.latitude,
                'longitude': z.longitude,
              })
          .toList(),
      'latitude': withCoords.isEmpty ? null : withCoords.first.latitude,
      'longitude': withCoords.isEmpty ? null : withCoords.first.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
