import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/geo_point.dart';
import 'camera_controller.dart';
import 'live_map_commands.dart';
import 'live_marker_layer.dart';
import 'marker_interpolator.dart';
import 'night_tile_layer.dart';
import 'trail_layer.dart';

/// The dark OpenStreetMap live map: trails underneath, riders on top, camera
/// following this rider.
///
/// A single ticker drives marker motion, prediction, the markers' idle float
/// and pulse, and camera follow. It runs while there are riders on the map
/// and stops when there are none. While only the slow ambient motion is
/// playing, markers repaint on every other frame. Map tiles and trails sit
/// below the markers' own repaint boundary, so marker frames never repaint
/// them.
class OsmMapWidget extends StatefulWidget {
  const OsmMapWidget({
    super.key,
    required this.initialCenter,
    required this.markers,
    required this.trails,
    required this.nowMs,
    required this.myUid,
    required this.riderCardBuilder,
    required this.bottomInset,
    this.routeLayer,
    this.headingOverride,
    this.returnTarget,
    this.commands,
    this.completionPoint,
    this.completionColor = AppColors.textPrimary,
  });

  /// Once the ride is over: where it finished. A marker springs in there.
  final GeoPoint? completionPoint;

  /// The colour of the completion marker: the rider's own.
  final Color completionColor;

  /// Drawn between the tiles and the trails: a guided ride's route.
  final Widget? routeLayer;

  /// A steadier direction for the camera than GPS heading (the route's own
  /// direction while on a guided route); `null` uses this rider's heading.
  final double? headingOverride;

  /// Off route: where to head back to. A dashed line runs to it from this
  /// rider's marker.
  final GeoPoint? returnTarget;

  /// Lets the screen recenter the camera, frame the route or focus a point.
  final LiveMapCommands? commands;

  /// Height of the bottom panel covering the map, in pixels. Read every frame
  /// by the camera and never rebuilds the map.
  final ValueListenable<double> bottomInset;

  /// Builds the floating card for the rider with the given uid.
  final Widget Function(String uid) riderCardBuilder;

  final GeoPoint initialCenter;
  final List<MarkerTarget> markers;
  final List<TrailStyle> trails;
  final int nowMs;

  /// The rider the camera follows.
  final String? myUid;

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<OsmMapWidget>
    with SingleTickerProviderStateMixin
    implements LiveMapTarget {
  final MapController _mapController = MapController();
  final MarkerInterpolator _interpolator = MarkerInterpolator();
  final ValueNotifier<int> _frames = ValueNotifier<int>(0);
  final Stopwatch _clock = Stopwatch()..start();
  late final FollowCameraController _camera = FollowCameraController(
    _mapController,
  );
  late final Ticker _ticker = createTicker((_) => _onFrame());
  Timer? _resumeTimer;
  bool _mapReady = false;

  /// The other rider whose info card is open, if any.
  String? _selectedUid;

  /// Alternates every frame; used to halve the marker frame rate while only
  /// ambient motion is playing.
  bool _idleFrame = false;

  /// How close a tap must land to a rider's dot to select it.
  static const double _tapRadius = 28;

  static const double _initialZoom = 16;
  static const double _minZoom = 3;
  static const double _maxZoom = NightTileLayer.maxZoom;

  Duration get _now => _clock.elapsed;

  @override
  void initState() {
    super.initState();
    _interpolator.update(widget.markers, _now);
    _camera.setBottomInset(widget.bottomInset.value, _now);
    widget.bottomInset.addListener(_onInsetChanged);
    widget.commands?.attach(this);
  }

  /// Space kept around a framed route, beyond the panels over the map.
  static const double _overviewMargin = 40;
  static const double _overviewTop = 150;
  static const double _focusZoom = 16;

  @override
  void recenter() {
    if (!_mapReady) return;
    _camera.resume(_now);
    _ensureTicking();
  }

  @override
  void showOverview(List<GeoPoint> points) {
    if (!_mapReady || points.length < 2) return;
    final fit = CameraFit.coordinates(
      coordinates: [for (final p in points) LatLng(p.latitude, p.longitude)],
      padding: EdgeInsets.fromLTRB(
        _overviewMargin,
        _overviewTop,
        _overviewMargin,
        widget.bottomInset.value + _overviewMargin,
      ),
      maxZoom: _initialZoom,
    ).fit(_mapController.camera);
    final now = _now;
    _camera
      ..hold(now)
      ..flyTo(fit.center, fit.zoom, now);
    _ensureTicking();
  }

  @override
  void focus(GeoPoint point) {
    if (!_mapReady) return;
    final now = _now;
    final zoom = _mapController.camera.zoom;
    _camera
      ..hold(now)
      ..flyTo(
        LatLng(point.latitude, point.longitude),
        zoom < _focusZoom ? _focusZoom : zoom,
        now,
      );
    _ensureTicking();
  }

  void _onInsetChanged() {
    _camera.setBottomInset(widget.bottomInset.value, _now);
    _ensureTicking();
  }

  @override
  void didUpdateWidget(OsmMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = _now;
    _interpolator.update(widget.markers, now);
    if (_interpolator.isAnimating(now) || _interpolator.hasMarkers) {
      _ensureTicking();
    }
    // A rider who disconnects (or leaves) loses their marker; close their card
    // straight away rather than leaving it pointing at nothing.
    final selected = _selectedUid;
    if (selected != null && !widget.markers.any((m) => m.uid == selected)) {
      _selectedUid = null;
    }
    if (!identical(oldWidget.commands, widget.commands)) {
      oldWidget.commands?.detach(this);
      widget.commands?.attach(this);
    }
    if (oldWidget.headingOverride != widget.headingOverride) _ensureTicking();
  }

  @override
  void dispose() {
    widget.commands?.detach(this);
    widget.bottomInset.removeListener(_onInsetChanged);
    _resumeTimer?.cancel();
    _ticker.dispose();
    _frames.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _ensureTicking() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _onFrame() {
    final now = _now;
    final uid = widget.myUid;
    if (_mapReady) _camera.stepFlight(now);
    if (_mapReady && uid != null && _camera.isActive(now)) {
      _camera.tick(
        _interpolator.positionOf(uid, now),
        widget.headingOverride ?? _interpolator.headingOf(uid, now),
        now,
        speedMps: _interpolator.speedOf(uid, now),
      );
    }
    final following = widget.commands?.isFollowing;
    if (following != null && following.value != _camera.isFollowing) {
      following.value = _camera.isFollowing;
    }
    final busy =
        _interpolator.isAnimating(now) ||
        _camera.isEasing(now) ||
        _camera.isFlying;
    // While only the slow idle float and pulse are playing, markers repaint
    // on every other frame: the motion looks the same and the GPU does half
    // the work for most of a ride spent cruising or standing.
    _idleFrame = !_idleFrame;
    if (busy || _selectedUid != null || !_idleFrame) _frames.value++;
    if (busy || _interpolator.hasMarkers) return;
    _ticker.stop();
    if (!_camera.isActive(now) && !_camera.isHeld) {
      // Paused by a manual pan: sleep until following may resume, instead of
      // rendering idle frames.
      _resumeTimer?.cancel();
      _resumeTimer = Timer(_camera.timeUntilResume(now), _ensureTicking);
    }
  }

  /// Opens the card of the nearest other rider under the tap; a tap anywhere
  /// else closes it.
  void _onTap(TapPosition tap, LatLng _) {
    final camera = _mapController.camera;
    final now = _now;
    String? hit;
    var best = _tapRadius;
    for (final frame in _interpolator.sample(now)) {
      if (frame.isMe || frame.opacity < 0.5) continue;
      final screen = camera.latLngToScreenOffset(
        LatLng(frame.point.latitude, frame.point.longitude),
      );
      final distance = (screen - tap.relative!).distance;
      if (distance <= best) {
        best = distance;
        hit = frame.uid;
      }
    }
    if (hit == _selectedUid) {
      if (hit == null) return;
      // Tapping the open rider again closes the card.
      hit = null;
    }
    setState(() => _selectedUid = hit);
    if (hit != null) {
      AppHaptics.selection();
      _ensureTicking();
    }
  }

  void _onMapEvent(MapEvent event) {
    _camera.onMapEvent(event, _now);
    _ensureTicking();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialCenter;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(center.latitude, center.longitude),
        initialZoom: _initialZoom,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        backgroundColor: AppColors.background,
        // Every gesture (the default interaction options), rotation included:
        // two fingers turn the map, as in Google Maps, and the camera then
        // keeps the chosen bearing until the follow button restores
        // heading-up.
        onMapReady: () {
          _mapReady = true;
          _ensureTicking();
        },
        onMapEvent: _onMapEvent,
        onTap: _onTap,
      ),
      children: [
        const NightTileLayer(),
        ?widget.routeLayer,
        TrailLayer(trails: widget.trails, nowMs: widget.nowMs),
        if (widget.returnTarget != null && widget.myUid != null)
          _ReturnLineLayer(
            target: widget.returnTarget!,
            uid: widget.myUid!,
            interpolator: _interpolator,
            frames: _frames,
            clock: () => _now,
          ),
        if (widget.completionPoint != null)
          MarkerLayer(
            // Stays upright however the map is turned.
            rotate: true,
            markers: [
              Marker(
                point: LatLng(
                  widget.completionPoint!.latitude,
                  widget.completionPoint!.longitude,
                ),
                width: _CompletionMarker.size,
                height: _CompletionMarker.size,
                child: _CompletionMarker(color: widget.completionColor),
              ),
            ],
          ),
        LiveMarkerLayer(
          interpolator: _interpolator,
          frames: _frames,
          clock: () => _now,
        ),
        // One animation drives the card both ways: it springs out of the dot
        // on opening and shrinks back into it on closing. The card layer
        // reads it from [_CardMotion], so it can scale about the dot itself.
        AnimatedSwitcher(
          duration: AppMotion.springDuration,
          reverseDuration: AppMotion.normal,
          transitionBuilder: (child, animation) =>
              _CardMotion(animation: animation, child: child),
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: _selectedUid == null
              ? const SizedBox.shrink(key: ValueKey('no-card'))
              : _RiderCardLayer(
                  key: ValueKey(_selectedUid),
                  uid: _selectedUid!,
                  interpolator: _interpolator,
                  frames: _frames,
                  clock: () => _now,
                  card: widget.riderCardBuilder(_selectedUid!),
                  onGone: () {
                    if (mounted) setState(() => _selectedUid = null);
                  },
                ),
        ),
      ],
    );
  }
}

/// Holds [card] just above a rider's dot and keeps it attached as the rider
/// moves and the map pans, zooms or turns. Closes itself if the rider leaves.
class _RiderCardLayer extends StatelessWidget {
  const _RiderCardLayer({
    super.key,
    required this.uid,
    required this.interpolator,
    required this.frames,
    required this.clock,
    required this.card,
    required this.onGone,
  });

  final String uid;
  final MarkerInterpolator interpolator;
  final Listenable frames;
  final Duration Function() clock;
  final Widget card;
  final VoidCallback onGone;

  /// The card's size, relative to rest, as it starts to open and finishes
  /// closing.
  static const double _closedScale = 0.82;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final motion = _CardMotion.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([frames, motion]),
        child: card,
        builder: (context, child) {
          final position = interpolator.positionOf(uid, clock());
          if (position == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onGone());
            return const SizedBox.shrink();
          }
          final anchor = camera.latLngToScreenOffset(
            LatLng(position.latitude, position.longitude),
          );
          final t = motion.value;
          // Opening springs (with a touch of overshoot); closing runs the
          // same path back, accelerating into the dot.
          final grow = motion.status == AnimationStatus.reverse
              ? AppMotion.curve.transform(t)
              : AppMotion.spring.transform(t);
          return CustomSingleChildLayout(
            delegate: _CardLayout(anchor),
            child: Opacity(
              // Fully visible early in the spring, gone early on the way out.
              opacity: (t * 1.6).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _closedScale + (1 - _closedScale) * grow,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Hands the card's open/close animation from the switcher down to the card
/// layer, which applies it around the rider's dot.
class _CardMotion extends InheritedWidget {
  const _CardMotion({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CardMotion>()?.animation ??
      kAlwaysCompleteAnimation;

  @override
  bool updateShouldNotify(_CardMotion oldWidget) =>
      oldWidget.animation != animation;
}

class _CardLayout extends SingleChildLayoutDelegate {
  const _CardLayout(this.anchor);

  final Offset anchor;

  static const double _gap = 26;
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = size.width - childSize.width - _margin;
    final x = (anchor.dx - childSize.width / 2).clamp(
      _margin,
      maxX < _margin ? _margin : maxX,
    );
    var y = anchor.dy - childSize.height - _gap;
    if (y < _margin) y = anchor.dy + _gap;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_CardLayout oldDelegate) => oldDelegate.anchor != anchor;
}

/// Off route: a dashed line from this rider's marker back to the route, so
/// the way back is obvious at a glance. It starts at the drawn (gliding)
/// marker, so it never lags behind it.
class _ReturnLineLayer extends StatelessWidget {
  const _ReturnLineLayer({
    required this.target,
    required this.uid,
    required this.interpolator,
    required this.frames,
    required this.clock,
  });

  final GeoPoint target;
  final String uid;
  final MarkerInterpolator interpolator;
  final Listenable frames;
  final Duration Function() clock;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ReturnLinePainter(
            camera: camera,
            target: target,
            from: () => interpolator.positionOf(uid, clock()),
            repaint: frames,
          ),
        ),
      ),
    );
  }
}

class _ReturnLinePainter extends CustomPainter {
  _ReturnLinePainter({
    required this.camera,
    required this.target,
    required this.from,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final MapCamera camera;
  final GeoPoint target;
  final GeoPoint? Function() from;

  static const double _dash = 7;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final start = from();
    if (start == null) return;
    final a = camera.latLngToScreenOffset(
      LatLng(start.latitude, start.longitude),
    );
    final b = camera.latLngToScreenOffset(
      LatLng(target.latitude, target.longitude),
    );
    final line = b - a;
    final length = line.distance;
    if (length < 4) return;
    final unit = line / length;
    final paint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    // Start clear of the marker's ring.
    for (var d = 14.0; d < length - 4; d += _dash + _gap) {
      final end = d + _dash > length - 4 ? length - 4 : d + _dash;
      canvas.drawLine(a + unit * d, a + unit * end, paint);
    }
    canvas
      ..drawCircle(b, 6, Paint()..color = AppColors.background)
      ..drawCircle(
        b,
        4.5,
        Paint()
          ..color = AppColors.textPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_ReturnLinePainter old) =>
      old.camera != camera || old.target != target;
}

/// Marks where the ride finished: a disc in the rider's colour with a check,
/// which springs in, with one ring spreading out from it and fading.
class _CompletionMarker extends StatefulWidget {
  const _CompletionMarker({required this.color});

  final Color color;

  static const double size = 64;

  @override
  State<_CompletionMarker> createState() => _CompletionMarkerState();
}

class _CompletionMarkerState extends State<_CompletionMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pop = AppMotion.spring.transform(
            const Interval(0, 0.5).transform(_controller.value),
          );
          final ring = const Interval(0.25, 1).transform(_controller.value);
          return CustomPaint(
            painter: _CompletionPainter(
              color: widget.color,
              pop: pop,
              ring: ring,
            ),
          );
        },
      ),
    );
  }
}

class _CompletionPainter extends CustomPainter {
  const _CompletionPainter({
    required this.color,
    required this.pop,
    required this.ring,
  });

  final Color color;
  final double pop;
  final double ring;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const base = 14.0;
    if (ring > 0 && ring < 1) {
      canvas.drawCircle(
        center,
        base + (size.shortestSide / 2 - base) * Curves.easeOutCubic.transform(ring),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.6 * (1 - ring)),
      );
    }
    final r = base * pop;
    canvas
      ..drawCircle(center, r + 3, Paint()..color = AppColors.background)
      ..drawCircle(center, r, Paint()..color = color);
    if (pop > 0.6) {
      final s = r * 0.42;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - s, center.dy + s * 0.05)
          ..lineTo(center.dx - s * 0.2, center.dy + s * 0.7)
          ..lineTo(center.dx + s, center.dy - s * 0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.background,
      );
    }
  }

  @override
  bool shouldRepaint(_CompletionPainter old) =>
      old.pop != pop || old.ring != ring || old.color != color;
}
