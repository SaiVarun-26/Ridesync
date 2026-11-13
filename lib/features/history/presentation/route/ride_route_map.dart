import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../../ride/presentation/map/night_tile_layer.dart';
import '../../domain/ride_details.dart';
import '../../domain/speed_scale.dart';
import '../../domain/u_turn_detector.dart';
import 'route_layer.dart';
import 'route_markers.dart';
import 'route_scene.dart';

/// The animations that bring a ride's route onto the map, in the order they
/// play. All run from 0 to 1. Defaults show everything straight away.
class RouteReveal {
  const RouteReveal({
    this.camera = const AlwaysStoppedAnimation<double>(1),
    this.draw = const AlwaysStoppedAnimation<double>(1),
    this.heat = const AlwaysStoppedAnimation<double>(1),
    this.startMarker = const AlwaysStoppedAnimation<double>(1),
    this.finishMarker = const AlwaysStoppedAnimation<double>(1),
    this.arrows = const AlwaysStoppedAnimation<double>(1),
  });

  /// The camera settling from a wider view onto the whole ride.
  final Animation<double> camera;

  /// The route being drawn from start to finish.
  final Animation<double> draw;

  /// Speed colours replacing the rider colours.
  final Animation<double> heat;

  final Animation<double> startMarker;

  /// The finish flag and the turn-around markers.
  final Animation<double> finishMarker;

  final Animation<double> arrows;
}

/// The interactive map of a finished ride.
///
/// Every rider's route is drawn coloured by speed with direction arrows, the
/// start and the finish are marked, and turn-around points are flagged. The
/// map pans, pinch-zooms and rotates freely and never snaps back to north-up.
/// Tapping a route highlights that rider; tapping it again, or empty map,
/// shows everyone again.
class RideRouteMap extends StatefulWidget {
  const RideRouteMap({
    super.key,
    required this.details,
    required this.colors,
    required this.myUid,
    required this.selectedUid,
    required this.onSelect,
    required this.topInset,
    required this.bottomInset,
    this.reveal = const RouteReveal(),
    this.onReady,
    this.onInteract,
  });

  final RideDetails details;

  /// Each rider's colour, by uid.
  final Map<String, Color> colors;
  final String? myUid;

  /// The highlighted rider, if any.
  final String? selectedUid;
  final ValueChanged<String?> onSelect;

  /// Space at the top and bottom of the map taken by other controls; the ride
  /// is fitted into what is left.
  final double topInset;
  final double bottomInset;

  final RouteReveal reveal;

  /// Called once, when the map has been laid out and can be shown.
  final VoidCallback? onReady;

  /// Called when the viewer first touches the map, so an intro animation can
  /// get out of the way.
  final VoidCallback? onInteract;

  @override
  State<RideRouteMap> createState() => RideRouteMapState();
}

class RideRouteMapState extends State<RideRouteMap> {
  final MapController _controller = MapController();
  final ValueNotifier<double> _rotation = ValueNotifier<double>(0);

  late RouteScene _scene;
  late SpeedScale _scale;
  late bool _hasSpeeds;
  late LatLngBounds _bounds;
  final Map<String, List<LatLng>> _uTurns = {};

  /// Where the camera comes to rest, once the map is ready.
  MapCamera? _restCamera;
  bool _cameraIntroDone = false;

  static const double _fitSideInset = 36;
  static const double _maxFitZoom = 17;

  /// How much wider than the final view the camera starts.
  static const double _introZoomOut = 1.3;

  @override
  void initState() {
    super.initState();
    _prepare();
    widget.reveal.camera.addListener(_onCameraIntro);
  }

  @override
  void didUpdateWidget(RideRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.details, widget.details) ||
        !identical(oldWidget.colors, widget.colors)) {
      _prepare();
    }
  }

  @override
  void dispose() {
    widget.reveal.camera.removeListener(_onCameraIntro);
    _rotation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _prepare() {
    final routes = widget.details.routes;
    _scale = SpeedScale.fromSeries([
      for (final r in routes.values)
        if (r.hasSpeeds) r.smoothedSpeedsMps,
    ]);
    _hasSpeeds = routes.values.any((r) => r.hasSpeeds);
    _scene = RouteScene.build(
      routes: routes,
      colors: widget.colors,
      scale: _scale,
    );
    _bounds = _boundsOf(routes);
    _uTurns
      ..clear()
      ..addEntries([
        for (final entry in routes.entries)
          MapEntry(entry.key, [
            for (final i in UTurnDetector.find(entry.value.points))
              LatLng(
                entry.value.points[i].latitude,
                entry.value.points[i].longitude,
              ),
          ]),
      ]);
  }

  static LatLngBounds _boundsOf(Map<String, RiderRoute> routes) {
    var south = double.infinity;
    var north = -double.infinity;
    var west = double.infinity;
    var east = -double.infinity;
    for (final route in routes.values) {
      for (final p in route.points) {
        south = math.min(south, p.latitude);
        north = math.max(north, p.latitude);
        west = math.min(west, p.longitude);
        east = math.max(east, p.longitude);
      }
    }
    // A ride that never left one spot still needs a box to fit.
    const minSpan = 0.0006;
    if (north - south < minSpan) {
      final middle = (north + south) / 2;
      south = middle - minSpan / 2;
      north = middle + minSpan / 2;
    }
    if (east - west < minSpan) {
      final middle = (east + west) / 2;
      west = middle - minSpan / 2;
      east = middle + minSpan / 2;
    }
    return LatLngBounds(LatLng(south, west), LatLng(north, east));
  }

  CameraFit _fit() => CameraFit.bounds(
    bounds: _bounds,
    padding: EdgeInsets.fromLTRB(
      _fitSideInset,
      widget.topInset + _fitSideInset,
      _fitSideInset,
      widget.bottomInset + _fitSideInset,
    ),
    maxZoom: _maxFitZoom,
  );

  /// Frames the whole ride again, north-up.
  void fitRoute() {
    _cameraIntroDone = true;
    _controller.fitCamera(_fit());
    _controller.rotate(0);
  }

  void _onMapReady() {
    final rest = _fit().fit(_controller.camera);
    _restCamera = rest;
    // Start wider than the final view; the viewer has not seen the map yet,
    // so there is no jump. The intro eases the camera in from here.
    if (widget.reveal.camera.value < 1) {
      _controller.move(rest.center, rest.zoom - _introZoomOut);
    } else {
      _cameraIntroDone = true;
    }
    widget.onReady?.call();
  }

  /// Eases the camera onto the whole ride while the intro plays.
  void _onCameraIntro() {
    final rest = _restCamera;
    if (rest == null || _cameraIntroDone) return;
    final t = AppMotion.curve.transform(widget.reveal.camera.value);
    _controller.move(rest.center, rest.zoom - _introZoomOut * (1 - t));
    if (widget.reveal.camera.value >= 1) _cameraIntroDone = true;
  }

  void _onPointerDown() {
    // The viewer has taken over: stop easing the camera.
    _cameraIntroDone = true;
    widget.onInteract?.call();
  }

  void _onTap(TapPosition tap, LatLng _) {
    final point = tap.relative;
    final hit = point == null
        ? null
        : _scene.riderNear(point, _controller.camera);
    widget.onSelect(hit == widget.selectedUid ? null : hit);
  }

  @override
  Widget build(BuildContext context) {
    final focusUid =
        widget.selectedUid ??
        (widget.details.routes.containsKey(widget.myUid)
            ? widget.myUid
            : widget.details.routes.keys.firstOrNull);
    final focus = focusUid == null ? null : _scene.rider(focusUid);
    final reveal = widget.reveal;

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (_) => _onPointerDown(),
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCameraFit: _fit(),
                backgroundColor: AppColors.background,
                minZoom: 3,
                maxZoom: NightTileLayer.maxZoom,
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag.drag |
                      InteractiveFlag.flingAnimation |
                      InteractiveFlag.pinchMove |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.rotate,
                ),
                onMapReady: _onMapReady,
                onTap: _onTap,
                onPositionChanged: (camera, _) {
                  if (_rotation.value != camera.rotation) {
                    _rotation.value = camera.rotation;
                  }
                },
              ),
              children: [
                const NightTileLayer(),
                RouteLayer(
                  scene: _scene,
                  selectedUid: widget.selectedUid,
                  reveal: reveal.draw,
                  heat: reveal.heat,
                  arrowsOpacity: reveal.arrows,
                ),
                if (focus != null) _markers(focus),
              ],
            ),
          ),
        ),
        Positioned(
          top: widget.topInset + AppSpacing.sm,
          right: AppSpacing.lg,
          child: _MapButtons(
            rotation: _rotation,
            onFit: fitRoute,
            onNorth: () => _controller.rotate(0),
          ),
        ),
        if (_hasSpeeds)
          Positioned(
            left: AppSpacing.lg,
            bottom: widget.bottomInset + AppSpacing.md,
            child: FadeTransition(
              opacity: reveal.heat,
              child: SpeedLegend(
                lowText: RideFormat.speed(_scale.lowMps),
                highText: RideFormat.speed(_scale.highMps),
              ),
            ),
          ),
      ],
    );
  }

  Widget _markers(RouteRider rider) {
    final uTurns = _uTurns[rider.uid] ?? const <LatLng>[];
    Widget appear(Animation<double> animation, Widget child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.6,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: AppMotion.spring)),
        child: child,
      ),
    );

    return MarkerLayer(
      rotate: true,
      markers: [
        for (final point in uTurns)
          Marker(
            point: point,
            width: UTurnMarker.size,
            height: UTurnMarker.size,
            child: appear(widget.reveal.finishMarker, const UTurnMarker()),
          ),
        Marker(
          point: rider.latLngs.first,
          child: appear(widget.reveal.startMarker, const StartMarker()),
        ),
        Marker(
          point: rider.latLngs.last,
          width: FinishFlagMarker.width,
          height: FinishFlagMarker.height,
          alignment: Alignment.topCenter,
          child: appear(widget.reveal.finishMarker, const FinishFlagMarker()),
        ),
      ],
    );
  }
}

class _MapButtons extends StatelessWidget {
  const _MapButtons({
    required this.rotation,
    required this.onFit,
    required this.onNorth,
  });

  final ValueListenable<double> rotation;
  final VoidCallback onFit;
  final VoidCallback onNorth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppIconButton(
          glass: true,
          icon: Icons.fit_screen_rounded,
          tooltip: 'Show whole ride',
          onPressed: onFit,
        ),
        ValueListenableBuilder<double>(
          valueListenable: rotation,
          builder: (context, degrees, _) {
            final turned = degrees.abs() > 0.5;
            return AnimatedSwitcher(
              duration: AppMotion.normal,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: turned
                  ? Padding(
                      key: const ValueKey('north'),
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: AppIconButton(
                        glass: true,
                        icon: Icons.navigation_rounded,
                        tooltip: 'Face north',
                        onPressed: onNorth,
                        child: Transform.rotate(
                          angle: -degrees * math.pi / 180,
                          child: const Icon(
                            Icons.navigation_rounded,
                            size: AppIconSize.medium,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey('no-north')),
            );
          },
        ),
      ],
    );
  }
}
