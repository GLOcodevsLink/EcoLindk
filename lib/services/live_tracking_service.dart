import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

/// Positions en direct des deux parties d'une collecte démarrée, dans
/// `liveTracking/{requestId}` — lisible/écrivable seulement par le
/// Fournisseur et le Collecteur de cette demande (voir firestore.rules).
/// Chacun n'écrit que SA propre position, et seulement pendant qu'il la
/// partage (voir [shareMyPosition]) : rien n'est suivi en arrière-plan.
class LiveTrackingSnapshot {
  final ll.LatLng? household;
  final ll.LatLng? collector;
  final DateTime? householdUpdatedAt;
  final DateTime? collectorUpdatedAt;
  const LiveTrackingSnapshot({
    this.household,
    this.collector,
    this.householdUpdatedAt,
    this.collectorUpdatedAt,
  });

  static ll.LatLng? _point(Map<String, dynamic>? d, String prefix) {
    final lat = (d?['${prefix}Lat'] as num?)?.toDouble();
    final lng = (d?['${prefix}Lng'] as num?)?.toDouble();
    return (lat == null || lng == null) ? null : ll.LatLng(lat, lng);
  }

  factory LiveTrackingSnapshot.fromMap(Map<String, dynamic>? d) => LiveTrackingSnapshot(
        household: _point(d, 'household'),
        collector: _point(d, 'collector'),
        householdUpdatedAt: (d?['householdUpdatedAt'] as Timestamp?)?.toDate(),
        collectorUpdatedAt: (d?['collectorUpdatedAt'] as Timestamp?)?.toDate(),
      );
}

enum TrackingRole { household, collector }

class LiveTrackingService {
  LiveTrackingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String requestId) =>
      _firestore.collection('liveTracking').doc(requestId);

  Stream<LiveTrackingSnapshot> watch(String requestId) =>
      _doc(requestId).snapshots().map((s) => LiveTrackingSnapshot.fromMap(s.data()));

  Future<void> updatePosition(
      String requestId, TrackingRole role, double latitude, double longitude) {
    final prefix = role.name;
    return _doc(requestId).set({
      '${prefix}Lat': latitude,
      '${prefix}Lng': longitude,
      '${prefix}UpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Envoie la position GPS de l'appareil à chaque déplacement de 10 m ou
  /// plus, jusqu'à l'annulation de l'abonnement renvoyé. La permission doit
  /// déjà avoir été accordée (voir GeoHelper.currentDeviceLocation).
  StreamSubscription<Position> shareMyPosition(String requestId, TrackingRole role) {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) => updatePosition(requestId, role, pos.latitude, pos.longitude));
  }

  /// Efface les positions une fois la collecte terminée — elles ne servent
  /// plus et n'ont pas à rester stockées.
  Future<void> clear(String requestId) async {
    try {
      await _doc(requestId).delete();
    } catch (_) {
      // Best-effort : l'échec du nettoyage ne doit jamais bloquer la
      // confirmation de la collecte elle-même.
    }
  }
}
