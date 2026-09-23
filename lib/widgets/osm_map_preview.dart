import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../core/theme.dart';

/// Couche de tuiles OpenStreetMap partagée par toute carte de l'app (aperçu
/// de position, carte du Collecteur…) — un seul endroit qui fixe l'URL des
/// tuiles et le `userAgentPackageName` (exigé par la politique d'usage des
/// tuiles OSM, voir https://operations.osmfoundation.org/policies/tiles/).
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.ecolindk.app',
    );

/// Aperçu de position — vraie carte OpenStreetMap (flutter_map), centrée sur
/// [latitude]/[longitude] avec un pin. L'aperçu lui-même reste figé (pas de
/// pan/zoom au doigt dedans, pour ne pas se battre avec le défilement de la
/// page qui l'entoure), mais il est TAPABLE : il ouvre [OsmMapDetailScreen],
/// une vraie carte OSM plein écran, pannable et zoomable, que l'utilisateur
/// peut rouvrir autant de fois qu'il veut pour regarder les environs en
/// détail (demande explicite : "l'utilisateur doit pouvoir la ouvrir encore
/// et encore pour la regarder en détail") — voir PostWasteScreen, étape
/// Adresse, et CollectorRequestPreviewScreen. Indique honnêtement quand la
/// position vient d'un géocodage d'adresse plutôt que d'une vraie lecture
/// GPS (voir GeoHelper/GeocodingService).
class MiniMapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool approximate;
  final bool fr;
  const MiniMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.approximate,
    this.fr = true,
  });

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OsmMapDetailScreen(
          latitude: latitude, longitude: longitude, approximate: approximate, fr: fr),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final point = ll.LatLng(latitude, longitude);
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 150,
          child: Stack(
            children: [
              // `interactionOptions.flags: none` — l'aperçu inline reste
              // figé (pas de pan/zoom au doigt en pleine liste) : c'est un
              // tap sur toute la carte qui ouvre la vraie carte détaillée
              // ([OsmMapDetailScreen]), pas un geste dans l'aperçu lui-même.
              FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  osmTileLayer(),
                  MarkerLayer(markers: [
                    Marker(
                      point: point,
                      width: 34,
                      height: 34,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on, color: AppColors.greenDeep, size: 34),
                    ),
                  ]),
                ],
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
                    '${approximate ? "  •  ${fr ? "approximatif" : "approximate"}" : ""}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Indice visuel que la carte s'ouvre en détail au tap — sans
              // ça rien ne distingue l'aperçu figé d'une carte interactive
              // normale, et le tap ne serait pas découvrable.
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vraie carte OpenStreetMap plein écran, pannable et zoomable normalement
/// (demande explicite) — ouverte depuis [MiniMapPreview], rouvrable autant
/// de fois que voulu (c'est un simple écran poussé sur la pile de
/// navigation, jamais un état mis en cache d'une ouverture à l'autre).
class OsmMapDetailScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool approximate;
  final bool fr;
  const OsmMapDetailScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.approximate,
    this.fr = true,
  });

  @override
  Widget build(BuildContext context) {
    final point = ll.LatLng(latitude, longitude);
    return Scaffold(
      appBar: AppBar(
        title: Text(fr ? "Position sur la carte" : "Location on the map"),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 16,
          // Pas de restriction ici (contrairement à MiniMapPreview) : pan
          // et zoom libres, comme une vraie carte à consulter.
        ),
        children: [
          osmTileLayer(),
          MarkerLayer(markers: [
            Marker(
              point: point,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: Icon(Icons.location_on, color: AppColors.greenDeep, size: 40),
            ),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
            '${approximate ? "  •  ${fr ? "position approximative" : "approximate position"}" : ""}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textGray),
          ),
        ),
      ),
    );
  }
}
