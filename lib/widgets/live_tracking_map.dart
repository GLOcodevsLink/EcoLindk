import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../core/theme.dart';
import '../models/collection_request.dart';
import '../services/geo_helper.dart';
import '../services/live_tracking_service.dart';
import 'osm_map_preview.dart';
import 'wp_common.dart';

/// Carte de suivi en temps réel d'une collecte démarrée — partagée par le
/// Collecteur (CollectorCollectionScreen) et le Fournisseur
/// (RequestStatusScreen). Affiche la position en direct des deux parties
/// (voir LiveTrackingService) et un bouton pour partager/arrêter de partager
/// SA propre position. Le partage s'arrête toujours en quittant l'écran.
class LiveTrackingMap extends StatefulWidget {
  final CollectionRequest request;
  final TrackingRole role;
  final bool fr;

  /// `true` côté Collecteur : il partage sa position dès l'ouverture, puisqu'il
  /// vient lui-même de démarrer la collecte.
  final bool autoShare;

  const LiveTrackingMap({
    super.key,
    required this.request,
    required this.role,
    required this.fr,
    this.autoShare = false,
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  final _service = LiveTrackingService();
  final _mapController = MapController();
  late final Stream<LiveTrackingSnapshot> _stream = _service.watch(widget.request.id);
  StreamSubscription<Position>? _sharing;
  bool _starting = false;
  String? _error;
  bool _mapReady = false;
  String? _lastFitKey;

  bool get _isSharing => _sharing != null;

  @override
  void initState() {
    super.initState();
    if (widget.autoShare) WidgetsBinding.instance.addPostFrameCallback((_) => _startSharing());
  }

  @override
  void dispose() {
    _sharing?.cancel();
    super.dispose();
  }

  Future<void> _startSharing() async {
    final fr = widget.fr;
    setState(() {
      _starting = true;
      _error = null;
    });
    final (location, result) = await GeoHelper.currentDeviceLocation();
    if (!mounted) return;
    if (location == null) {
      setState(() {
        _starting = false;
        _error = switch (result) {
          LocationPermissionResult.deniedForever => fr
              ? "Localisation bloquée — activez-la dans les réglages du téléphone."
              : "Location blocked — enable it in your phone settings.",
          LocationPermissionResult.serviceDisabled =>
            fr ? "Le GPS est désactivé sur cet appareil." : "GPS is turned off on this device.",
          _ => fr ? "Permission de localisation refusée." : "Location permission denied.",
        };
      });
      return;
    }
    await _service.updatePosition(
        widget.request.id, widget.role, location.latitude, location.longitude);
    if (!mounted) return;
    setState(() {
      _starting = false;
      _sharing = _service.shareMyPosition(widget.request.id, widget.role);
    });
  }

  void _stopSharing() {
    _sharing?.cancel();
    setState(() => _sharing = null);
  }

  void _fit(List<ll.LatLng> points) {
    if (!_mapReady || points.isEmpty) return;
    // Recadre seulement quand une position change réellement — pas à chaque
    // rebuild, pour ne pas annuler un déplacement manuel de la carte.
    final key = points.map((p) => '${p.latitude},${p.longitude}').join('|');
    if (key == _lastFitKey) return;
    _lastFitKey = key;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
    } else {
      _mapController.fitCamera(CameraFit.coordinates(
          coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 17));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fr = widget.fr;
    final postPoint = ll.LatLng(widget.request.latitude, widget.request.longitude);
    return StreamBuilder<LiveTrackingSnapshot>(
      stream: _stream,
      builder: (context, snap) {
        final live = snap.data ?? const LiveTrackingSnapshot();
        final household = live.household;
        final collector = live.collector;
        final points = [household ?? postPoint, if (collector != null) collector];
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit(points));

        final distanceKm = (household != null && collector != null)
            ? const ll.Distance().as(ll.LengthUnit.Meter, household, collector) / 1000
            : null;
        final otherShared =
            widget.role == TrackingRole.collector ? household != null : collector != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 240,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 14,
                    onMapReady: () {
                      _mapReady = true;
                      _fit(points);
                    },
                  ),
                  children: [
                    osmTileLayer(),
                    MarkerLayer(markers: [
                      Marker(
                        point: household ?? postPoint,
                        width: 40,
                        height: 40,
                        child: _pin(Icons.home_rounded, AppColors.greenDeep,
                            faded: household == null),
                      ),
                      if (collector != null)
                        Marker(
                          point: collector,
                          width: 40,
                          height: 40,
                          child: _pin(Icons.local_shipping_rounded, const Color(0xFF2094C4)),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(otherShared ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                    size: 16, color: otherShared ? AppColors.greenDeep : AppColors.textGray),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.role == TrackingRole.collector
                        ? (otherShared
                            ? (fr ? "Le fournisseur partage sa position" : "The supplier is sharing their location")
                            : (fr
                                ? "En attente que le fournisseur partage sa position (adresse du post affichée)"
                                : "Waiting for the supplier to share their location (post address shown)"))
                        : (otherShared
                            ? (fr ? "Le collecteur est en route" : "The collector is on the way")
                            : (fr ? "Position du collecteur pas encore reçue" : "Collector's location not received yet")),
                    style: TextStyle(fontSize: 11.5, color: AppColors.textGray),
                  ),
                ),
                if (distanceKm != null)
                  Text(
                    distanceKm < 1
                        ? "${(distanceKm * 1000).toStringAsFixed(0)} m"
                        : "${distanceKm.toStringAsFixed(1)} km",
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.greenDeep),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_starting)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4),
              ))
            else if (_isSharing)
              OutlinedButton.icon(
                onPressed: _stopSharing,
                icon: const Icon(Icons.location_disabled_rounded, size: 18),
                label: Text(fr ? "Arrêter de partager ma position" : "Stop sharing my location"),
              )
            else
              OutlinedButton.icon(
                onPressed: _startSharing,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(fr ? "Partager ma position" : "Share my location"),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              InlineErrorBanner(message: _error!),
            ],
          ],
        );
      },
    );
  }

  Widget _pin(IconData icon, Color color, {bool faded = false}) {
    return Container(
      decoration: BoxDecoration(
        color: faded ? color.withOpacity(0.55) : color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
