import 'dart:math';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionResult { granted, deniedOnce, deniedForever, serviceDisabled }

class ResolvedLocation {
  final double latitude;
  final double longitude;

  /// `true` quand ces coordonnées viennent du géocodage simulé d'une adresse
  /// tapée (voir [GeoHelper.approximateFromAddress]) plutôt que d'une vraie
  /// lecture GPS — l'UI doit alors afficher "approximatif", jamais faire
  /// comme si c'était une position précise.
  final bool isApproximate;

  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.isApproximate,
  });
}

/// Localisation pour la création d'une demande de collecte (voir règle
/// métier #6 : ne jamais demander la permission de localisation à
/// l'inscription — seulement ici, au moment où l'utilisateur choisit
/// "Utiliser le GPS").
class GeoHelper {
  const GeoHelper._();

  // Point de référence pour le géocodage simulé (Douala, Cameroun) — voir
  // [approximateFromAddress]. À remplacer par un vrai géocodage quand une
  // API de cartes sera branchée.
  static const _refLat = 4.0511;
  static const _refLng = 9.7679;

  static Future<LocationPermissionResult> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionResult.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return LocationPermissionResult.deniedOnce;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult.deniedForever;
    }
    return LocationPermissionResult.granted;
  }

  /// Position réelle de l'appareil (vrai GPS, pas simulé). Demande la
  /// permission seulement à cet instant.
  static Future<(ResolvedLocation?, LocationPermissionResult)>
      currentDeviceLocation() async {
    final permissionResult = await _ensurePermission();
    if (permissionResult != LocationPermissionResult.granted) {
      return (null, permissionResult);
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return (
      ResolvedLocation(
          latitude: pos.latitude, longitude: pos.longitude, isApproximate: false),
      permissionResult,
    );
  }

  /// Pas de vraie API de géocodage branchée pour l'instant (voir la suite du
  /// projet). Dérive des coordonnées stables (toujours les mêmes pour la
  /// même adresse tapée, via un hash) autour du point de référence, pour
  /// qu'un pin cohérent s'affiche quand même — toujours marqué
  /// [ResolvedLocation.isApproximate] pour rester honnête dans l'UI.
  static ResolvedLocation approximateFromAddress(String address) {
    final rnd = Random(address.trim().toLowerCase().hashCode);
    final dLat = (rnd.nextDouble() - 0.5) * 0.08; // ~ ± 4 km
    final dLng = (rnd.nextDouble() - 0.5) * 0.08;
    return ResolvedLocation(
        latitude: _refLat + dLat, longitude: _refLng + dLng, isApproximate: true);
  }
}
