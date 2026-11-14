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
  });

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
    with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
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
    if (_mapReady && uid != null && _camera.isActive(now)) {
      _camera.tick(
        _interpolator.positionOf(uid, now),
        _interpolator.headingOf(uid, now),
        now,
        speedMps: _interpolator.speedOf(uid, now),
      );
    }
    final busy = _interpolator.isAnimating(now) || _camera.isEasing(now);
    // While only the slow idle float and pulse are playing, markers repaint
    // on every other frame: the motion looks the same and the GPU does half
    // the work for most of a ride spent cruising or standing.
    _idleFrame = !_idleFrame;
    if (busy || _selectedUid != null || !_idleFrame) _frames.value++;
    if (busy || _interpolator.hasMarkers) return;
    _ticker.stop();
    if (!_camera.isActive(now)) {
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
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _mapReady = true;
          _ensureTicking();
        },
        onMapEvent: _onMapEvent,
        onTap: _onTap,
      ),
      children: [
        const NightTileLayer(),
        TrailLayer(trails: widget.trails, nowMs: widget.nowMs),
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
