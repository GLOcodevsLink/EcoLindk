import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/geo_helper.dart';
import '../../widgets/osm_map_preview.dart';
import '../../widgets/wp_common.dart';
import 'collector_request_preview_screen.dart';

/// Carte du Collecteur : toutes les demandes encore libres (`pending`, tous
/// fournisseurs confondus — voir CollectionService.watchAvailableRequests),
/// une Marker par demande sur une vraie carte OpenStreetMap (flutter_map),
/// ET une liste scrollable des mêmes demandes juste en dessous (adresse +
/// infos principales) — taper une Marker OU un élément de la liste ouvre la
/// même page de détails (CollectorRequestPreviewScreen).
///
/// Bonus "proche de moi" : DEUX sources de position comptent (demande
/// explicite), pas seulement le GPS — le point de référence géocodé de la
/// "zone de collecte" déclarée dans le profil (voir
/// CollectionService.getCollectorLocation/ProfileScreen) ET la position GPS
/// réelle de l'appareil au moment où le Collecteur consulte cet écran (voir
/// GeoHelper, redemandée à chaque ouverture — jamais mise en cache d'une
/// session à l'autre). Le filtre optionnel ne garde que les demandes à moins
/// de 10 km de L'UNE OU L'AUTRE de ces deux positions, triées par distance à
/// la plus proche des deux.
class CollectorMapScreen extends StatefulWidget {
  const CollectorMapScreen({super.key});

  @override
  State<CollectorMapScreen> createState() => _CollectorMapScreenState();
}

class _CollectorMapScreenState extends State<CollectorMapScreen> {
  final _collectionService = CollectionService();
  final _mapController = MapController();
  final _distance = const ll.Distance();

  static const _nearbyRadiusKm = 10.0;
  // Douala, Cameroun — centre par défaut tant que la position réelle de
  // l'appareil n'a pas encore été obtenue (voir [_locateMe]).
  static const _defaultCenter = ll.LatLng(4.0511, 9.7679);

  ll.LatLng? _myPosition; // GPS live, redemandé à chaque ouverture de l'écran.
  ll.LatLng? _zonePosition; // Zone de collecte géocodée (profil), relue depuis Firestore.
  bool _locating = false;
  bool _nearbyOnly = false;

  @override
  void initState() {
    super.initState();
    _locateMe();
    _loadZonePosition();
  }

  Future<void> _locateMe() async {
    setState(() => _locating = true);
    final (location, _) = await GeoHelper.currentDeviceLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (location != null) {
        _myPosition = ll.LatLng(location.latitude, location.longitude);
        _mapController.move(_myPosition!, 13);
      }
    });
  }

  Future<void> _loadZonePosition() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    final zone = await _collectionService.getCollectorLocation(uid);
    if (!mounted || zone == null) return;
    setState(() {
      _zonePosition = zone;
      // Ne recentre que si le GPS live n'a pas déjà pris la main (sinon on
      // préfère toujours la position live, plus précise et plus fraîche).
      if (_myPosition == null) _mapController.move(_zonePosition!, 12);
    });
  }

  /// Distance minimale de [point] à la plus proche des deux positions de
  /// référence disponibles (zone de collecte, GPS live) — `null` si aucune
  /// des deux n'est disponible.
  double? _minDistanceKm(ll.LatLng point) {
    double? best;
    for (final ref in [_zonePosition, _myPosition]) {
      if (ref == null) continue;
      final km = _distance.as(ll.LengthUnit.Kilometer, ref, point);
      if (best == null || km < best) best = km;
    }
    return best;
  }

  List<CollectionRequest> _visible(List<CollectionRequest> all) {
    if (!_nearbyOnly || (_myPosition == null && _zonePosition == null)) return all;
    final withDistance = all
        .map((r) => (r, _minDistanceKm(ll.LatLng(r.latitude, r.longitude))))
        .where((e) => e.$2 != null && e.$2! <= _nearbyRadiusKm)
        .toList()
      ..sort((a, b) => a.$2!.compareTo(b.$2!));
    return withDistance.map((e) => e.$1).toList();
  }

  void _openPreview(CollectionRequest r) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CollectorRequestPreviewScreen(request: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        return StreamBuilder<List<CollectionRequest>>(
          stream: _collectionService.watchAvailableRequests(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4));
            }
            if (snap.hasError) {
              return Center(
                child: InlineErrorBanner(
                  message: fr
                      ? "Impossible de charger les collectes disponibles."
                      : "Couldn't load available pickups.",
                ),
              );
            }
            final all = snap.data ?? const [];
            final items = _visible(all);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fr
                              ? "${all.length} collecte(s) disponible(s)"
                              : "${all.length} available pickup(s)",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textGray),
                        ),
                      ),
                      _nearbyChip(fr),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _myPosition ?? _zonePosition ?? _defaultCenter,
                            initialZoom: 12,
                          ),
                          children: [
                            osmTileLayer(),
                            MarkerLayer(markers: [
                              if (_zonePosition != null)
                                Marker(
                                  point: _zonePosition!,
                                  width: 26,
                                  height: 26,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.amber,
                                      border: Border.all(color: Colors.white, width: 3),
                                    ),
                                    child: const Icon(Icons.home_outlined, color: Colors.white, size: 12),
                                  ),
                                ),
                              if (_myPosition != null)
                                Marker(
                                  point: _myPosition!,
                                  width: 22,
                                  height: 22,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF2094C4),
                                      border: Border.all(color: Colors.white, width: 3),
                                    ),
                                  ),
                                ),
                              for (final r in items)
                                Marker(
                                  point: ll.LatLng(r.latitude, r.longitude),
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.topCenter,
                                  child: GestureDetector(
                                    onTap: () => _openPreview(r),
                                    child: Icon(Icons.location_on,
                                        color: AppColors.greenDeep, size: 40),
                                  ),
                                ),
                            ]),
                          ],
                        ),
                        if (_locating)
                          const Positioned(
                            top: 10,
                            right: 10,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.greenMid),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 4,
                  child: items.isEmpty
                      ? EmptyState(
                          icon: Icons.map_outlined,
                          color: const Color(0xFF2094C4),
                          title: fr ? "Aucune collecte disponible" : "No pickup available",
                          message: _nearbyOnly
                              ? (fr
                                  ? "Aucune collecte à moins de ${_nearbyRadiusKm.toInt()} km. Désactivez le filtre pour tout voir."
                                  : "No pickup within ${_nearbyRadiusKm.toInt()} km. Turn off the filter to see all.")
                              : (fr
                                  ? "Revenez plus tard — de nouvelles demandes apparaîtront ici."
                                  : "Check back later — new requests will show up here."),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _tile(items[i], fr),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _nearbyChip(bool fr) {
    return GestureDetector(
      onTap: (_myPosition == null && _zonePosition == null)
          ? _locateMe
          : () => setState(() => _nearbyOnly = !_nearbyOnly),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _nearbyOnly ? AppColors.greenMid.withOpacity(0.15) : AppColors.inputFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _nearbyOnly ? AppColors.greenMid : AppColors.line, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me_outlined,
                size: 14, color: _nearbyOnly ? AppColors.greenDeep : AppColors.textGray),
            const SizedBox(width: 4),
            Text(fr ? "Près de moi" : "Near me",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _nearbyOnly ? AppColors.greenDeep : AppColors.textGray)),
          ],
        ),
      ),
    );
  }

  Widget _tile(CollectionRequest r, bool fr) {
    final km = _minDistanceKm(ll.LatLng(r.latitude, r.longitude));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openPreview(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.2),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: r.imageUrl.isEmpty
                  ? Container(
                      width: 48,
                      height: 48,
                      color: AppColors.inputFill,
                      child: Icon(r.category.icon, color: AppColors.greenMid))
                  : Image.network(r.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.category.label(fr),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                  Text(r.address.isEmpty ? '—' : r.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                ],
              ),
            ),
            if (km != null)
              Text("${km.toStringAsFixed(1)} km",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
          ],
        ),
      ),
    );
  }
}
