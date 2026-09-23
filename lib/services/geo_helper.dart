import 'package:geolocator/geolocator.dart';

enum LocationPermissionResult { granted, deniedOnce, deniedForever, serviceDisabled }

class ResolvedLocation {
  final double latitude;
  final double longitude;

  /// `true` quand ces coordonnées viennent du géocodage d'une adresse tapée
  /// (voir GeocodingService, appelé depuis PostWasteScreen) plutôt que d'une
  /// vraie lecture GPS — l'UI affiche alors "approximatif" (l'adresse peut
  /// être moins précise qu'une position GPS directe), jamais comme si
  /// c'était une position mesurée sur l'appareil.
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
}
