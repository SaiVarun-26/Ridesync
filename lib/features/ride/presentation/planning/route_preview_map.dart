import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/geo_point.dart';
import '../../domain/guidance/route_guide.dart';
import '../map/guided_route_layer.dart';
import '../map/night_tile_layer.dart';

/// The route overview while a guided ride is being planned.
///
/// Shows where the group starts and, once the host has picked a destination,
/// the whole route drawing itself in from start to finish while the camera
/// glides out to frame it. The host can long-press anywhere to drop the
/// destination there.
class RoutePreviewMap extends StatefulWidget {
  const RoutePreviewMap({
    super.key,
    required this.guide,
    required this.origin,
    required this.pendingDestination,
    required this.padding,
    this.onLongPress,
  });

  final RouteGuide? guide;

  /// Where the group starts (the host's position), when known.
  final GeoPoint? origin;

  /// A destination picked but not routed yet.
  final GeoPoint? pendingDestination;

  /// Space covered by the panels above and below the map.
  final EdgeInsets padding;

  final ValueChanged<GeoPoint>? onLongPress;

  @override
  State<RoutePreviewMap> createState() => _RoutePreviewMapState();
}

class _RoutePreviewMapState extends State<RoutePreviewMap>
    with TickerProviderStateMixin {
  final MapController _map = MapController();
  bool _ready = false;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    value: widget.guide == null ? 0 : 1,
  );

  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(_onFlight);

  LatLng? _fromCenter;
  double? _fromZoom;
  MapCamera? _toCamera;

  static const double _startZoom = 14;

  @override
  void didUpdateWidget(RoutePreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.guide != oldWidget.guide && widget.guide != null) {
      _reveal.forward(from: 0);
      _frameRoute();
    } else if (oldWidget.origin == null && widget.origin != null && _ready) {
      _flyTo(widget.origin!, _startZoom);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _flight.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _ready = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.guide != null) {
        _frameRoute(animate: false);
      } else if (widget.origin != null) {
        _map.move(
          LatLng(widget.origin!.latitude, widget.origin!.longitude),
          _startZoom,
        );
      }
    });
  }

  void _frameRoute({bool animate = true}) {
    final guide = widget.guide;
    if (!_ready || guide == null || !guide.isUsable) return;
    final fit = CameraFit.coordinates(
      coordinates: [
        for (final p in guide.geometry.points) LatLng(p.latitude, p.longitude),
      ],
      padding: widget.padding + const EdgeInsets.all(AppSpacing.xl),
      maxZoom: 16,
    ).fit(_map.camera);
    if (!animate) {
      _map.move(fit.center, fit.zoom);
      return;
    }
    _fromCenter = _map.camera.center;
    _fromZoom = _map.camera.zoom;
    _toCamera = fit;
    _flight.forward(from: 0);
  }

  void _flyTo(GeoPoint point, double zoom) {
    _fromCenter = _map.camera.center;
    _fromZoom = _map.camera.zoom;
    _toCamera = _map.camera.withPosition(
      center: LatLng(point.latitude, point.longitude),
      zoom: zoom,
    );
    _flight.forward(from: 0);
  }

  void _onFlight() {
    final from = _fromCenter;
    final fromZoom = _fromZoom;
    final to = _toCamera;
    if (from == null || fromZoom == null || to == null) return;
    final t = AppMotion.move.transform(_flight.value);
    _map.move(
      LatLng(
        from.latitude + (to.center.latitude - from.latitude) * t,
        from.longitude + (to.center.longitude - from.longitude) * t,
      ),
      fromZoom + (to.zoom - fromZoom) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final origin = widget.origin;
    final guide = widget.guide;
    final pending = widget.pendingDestination;
    final start = origin ?? guide?.geometry.start;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: start == null
            ? const LatLng(20, 0)
            : LatLng(start.latitude, start.longitude),
        initialZoom: start == null ? 3 : _startZoom,
        minZoom: 3,
        maxZoom: NightTileLayer.maxZoom,
        backgroundColor: AppColors.background,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: _onMapReady,
        onLongPress: widget.onLongPress == null
            ? null
            : (_, at) => widget.onLongPress!(
                GeoPoint(latitude: at.latitude, longitude: at.longitude),
              ),
      ),
      children: [
        const NightTileLayer(),
        if (guide != null)
          AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) => GuidedRouteLayer(
              guide: guide,
              reveal: AppMotion.move.transform(_reveal.value),
            ),
          ),
        MarkerLayer(
          markers: [
            if (origin != null && guide == null)
              Marker(
                point: LatLng(origin.latitude, origin.longitude),
                width: 22,
                height: 22,
                child: const _OriginDot(),
              ),
            if (pending != null && guide == null)
              Marker(
                point: LatLng(pending.latitude, pending.longitude),
                width: 22,
                height: 22,
                child: const _PendingPin(),
              ),
          ],
        ),
      ],
    );
  }
}

class _OriginDot extends StatelessWidget {
  const _OriginDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        border: Border.all(color: AppColors.textPrimary, width: 3),
      ),
    );
  }
}

class _PendingPin extends StatelessWidget {
  const _PendingPin();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.springDuration,
      curve: AppMotion.spring,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
          border: Border.all(color: AppColors.textPrimary, width: 3),
        ),
      ),
    );
  }
}
