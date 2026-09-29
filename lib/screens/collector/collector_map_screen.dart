import 'package:flutter/material.dart';
import '../../widgets/waste_photo_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../core/geo_config.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/collection_service.dart';
import '../../services/geo_helper.dart';
import '../../services/nearby_posts.dart';
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
/// Filtre "Autour de moi" : uniquement la position GPS ACTUELLE de
/// l'appareil (redemandée à chaque ouverture), jamais les zones de collecte
/// du profil — celles-ci ne servent qu'aux notifications (voir
/// CollectorZoneService). Un collecteur hors de ses zones trouve donc les
/// posts autour de lui, dans un rayon de [GeoConfig.gpsSearchRadiusKm] km,
/// triés du plus proche au plus loin (voir postsAroundPosition).
///
/// La carte se cadre d'abord sur les POSTES disponibles, jamais sur le seul
/// GPS de l'appareil : un GPS éloigné (ex. émulateur réglé par défaut aux
/// USA) laisserait sinon tous les postes hors de l'écran. Le bouton de
/// recadrage ramène la vue sur les postes à tout moment.
class CollectorMapScreen extends StatefulWidget {
  const CollectorMapScreen({super.key});

  @override
  State<CollectorMapScreen> createState() => _CollectorMapScreenState();
}

class _CollectorMapScreenState extends State<CollectorMapScreen> {
  final _collectionService = CollectionService();
  final _mapController = MapController();
  final _distance = const ll.Distance();

  static const _nearbyRadiusKm = GeoConfig.gpsSearchRadiusKm;
  // Douala, Cameroun — centre par défaut tant que la position réelle de
  // l'appareil n'a pas encore été obtenue (voir [_locateMe]).
  static const _defaultCenter = ll.LatLng(4.0511, 9.7679);

  ll.LatLng? _myPosition; // GPS live, redemandé à chaque ouverture de l'écran.
  bool _locating = false;
  bool _nearbyOnly = false;
  bool _mapReady = false;
  bool _fittedToPosts = false;
  List<CollectionRequest> _lastItems = const [];

  @override
  void initState() {
    super.initState();
    _locateMe();
  }

  Future<void> _locateMe() async {
    setState(() => _locating = true);
    final (location, _) = await GeoHelper.currentDeviceLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (location != null) {
        _myPosition = ll.LatLng(location.latitude, location.longitude);
        if (!_fittedToPosts && _mapReady) _mapController.move(_myPosition!, 13);
      }
    });
  }

  /// Distance (km) entre la position GPS actuelle et [point], `null` sans GPS.
  double? _distanceFromMeKm(ll.LatLng point) =>
      _myPosition == null ? null : _distance.as(ll.LengthUnit.Kilometer, _myPosition!, point);

  List<CollectionRequest> _visible(List<CollectionRequest> all) {
    final me = _myPosition;
    if (!_nearbyOnly || me == null) return all;
    return postsAroundPosition(all, me, radiusKm: _nearbyRadiusKm).map((e) => e.$1).toList();
  }

  /// Cadre la carte sur tous les postes affichés (un seul : centré dessus).
  void _fitToPosts(List<CollectionRequest> items) {
    if (!_mapReady || items.isEmpty) return;
    final points = items.map((r) => ll.LatLng(r.latitude, r.longitude)).toList();
    if (points.length == 1) {
      _mapController.move(points.first, 14);
    } else {
      _mapController.fitCamera(CameraFit.coordinates(
          coordinates: points, padding: const EdgeInsets.all(40), maxZoom: 15));
    }
    _fittedToPosts = true;
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
            _lastItems = items;
            if (!_fittedToPosts && items.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _fitToPosts(items));
            }

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
                            initialCenter: _myPosition ?? _defaultCenter,
                            initialZoom: 12,
                            onMapReady: () {
                              _mapReady = true;
                              _fitToPosts(_lastItems);
                            },
                          ),
                          children: [
                            osmTileLayer(),
                            MarkerLayer(markers: [
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
                        if (items.isNotEmpty)
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: Material(
                              color: AppColors.card,
                              shape: const CircleBorder(),
                              elevation: 3,
                              child: IconButton(
                                tooltip: fr ? "Voir tous les postes" : "Show all posts",
                                onPressed: () => _fitToPosts(items),
                                icon: const Icon(Icons.zoom_out_map_rounded,
                                    color: AppColors.greenDeep, size: 20),
                              ),
                            ),
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
                                  ? "Aucune collecte à moins de ${_nearbyRadiusKm.toInt()} km de votre position actuelle. Désactivez le filtre pour tout voir."
                                  : "No pickup within ${_nearbyRadiusKm.toInt()} km of your current position. Turn off the filter to see all.")
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
      // Sans position GPS, le filtre la redemande d'abord.
      onTap: _myPosition == null ? _locateMe : () => setState(() => _nearbyOnly = !_nearbyOnly),
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
            Icon(Icons.my_location_rounded,
                size: 14, color: _nearbyOnly ? AppColors.greenDeep : AppColors.textGray),
            const SizedBox(width: 4),
            Text(fr ? "Autour de moi (GPS)" : "Around me (GPS)",
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
    final km = _distanceFromMeKm(ll.LatLng(r.latitude, r.longitude));
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
                  : WastePhotoImage(url: r.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.category.label(fr),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                  Text(r.neighborhood ?? (r.address.isEmpty ? '—' : r.address),
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
