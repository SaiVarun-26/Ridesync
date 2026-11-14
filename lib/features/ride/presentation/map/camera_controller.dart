import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_spacing.dart';

import '../../domain/geo_point.dart';
import '../../domain/live/heading_smoother.dart';

/// Google Maps style navigation camera: keeps this rider near the lower third
/// of the screen, rotates the map so the direction of travel points up, and
/// keeps the rider's chosen zoom.
///
/// Rotation is presentation only: it follows the rider's smoothed heading and
/// is completely independent of what is uploaded to the group. While the rider
/// is stationary there is no heading, so rotation freezes instead of spinning.
///
/// The centre does not lock rigidly onto the marker: it follows through a
/// light, speed-aware low-pass filter (see [tick]), which takes out jitter
/// without letting the rider slide around the screen at speed.
///
/// Both following and rotating pause while the rider pans the map themselves,
/// and resume together after [resumeAfter] of no panning, easing back over
/// [_returnDuration] instead of snapping. Pinch-zoom never interrupts either.
class FollowCameraController {
  FollowCameraController(
    this._map, {
    this.resumeAfter = const Duration(seconds: 6),
    HeadingSmoother? heading,
  }) : _heading = heading ?? HeadingSmoother();

  final MapController _map;
  final Duration resumeAfter;
  final HeadingSmoother _heading;

  static const Duration _returnDuration = Duration(milliseconds: 700);

  /// Where the rider sits vertically, as a fraction of the map height from the
  /// top: two thirds down, leaving the road ahead in view.
  static const double _riderHeightFraction = 2 / 3;

  /// Rotation changes smaller than this (degrees) are not worth a camera move.
  static const double _rotationEpsilon = 0.01;

  /// Manual pans that pause following. Zoom gestures are not included.
  static const Set<MapEventSource> _panSources = {
    MapEventSource.dragStart,
    MapEventSource.onDrag,
    MapEventSource.flingAnimationController,
  };

  /// Height at the bottom of the map covered by the ride panel, in pixels.
  double _bottomInset = 0;
  Duration? _insetChangedAt;

  double get bottomInset => _bottomInset;

  /// How long the camera keeps following after the inset changes, so the
  /// rider glides to their new spot as the panel opens or closes.
  static const Duration _insetSettle = Duration(milliseconds: 450);

  /// Tells the camera how much of the map's bottom is covered.
  void setBottomInset(double value, Duration now) {
    if ((value - _bottomInset).abs() < 0.5) return;
    _bottomInset = value;
    _insetChangedAt = now;
  }

  Duration? _pausedAt;
  Duration? _returnStart;
  LatLng? _returnFrom;

  /// Whether the camera will move this frame (following, or easing back).
  bool isActive(Duration now) => _pausedAt == null || _shouldResume(now);

  /// Whether the camera is still easing at [now]: returning after a pan,
  /// catching up to a new heading, or adjusting to the panel. False while
  /// paused, so an idle paused map renders no frames.
  bool isEasing(Duration now) {
    if (_pausedAt != null) return false;
    final returning =
        _returnStart != null && now - _returnStart! < _returnDuration;
    final insetChanging =
        _insetChangedAt != null && now - _insetChangedAt! < _insetSettle;
    return returning ||
        insetChanging ||
        _heading.isSettling ||
        _lagPixels > _settledPixels;
  }

  /// Reports a map event; manual pans pause following and rotating.
  void onMapEvent(MapEvent event, Duration now) {
    if (_panSources.contains(event.source)) {
      _pausedAt = now;
      _returnStart = null;
      _lagPixels = 0;
    }
  }

  /// Moves and rotates the camera for the frame at [now].
  ///
  /// [target] is where this rider is drawn; [headingDegrees] is their drawn
  /// direction of travel, or `null` while stationary; [speedMps] is how fast
  /// they are going, which sets how tightly the camera tracks them.
  void tick(
    GeoPoint? target,
    double? headingDegrees,
    Duration now, {
    double speedMps = 0,
  }) {
    if (target == null) return;
    if (_pausedAt != null) {
      if (!_shouldResume(now)) return;
      _pausedAt = null;
      _returnStart = now;
      _returnFrom = _map.camera.center;
      _smoothed = null;
    }

    final camera = _map.camera;
    final smoothed = _heading.step(headingDegrees, now);
    // Heading-up: turning the map counter-clockwise by the heading puts the
    // direction of travel at the top of the screen.
    final rotation = smoothed == null ? camera.rotation : -smoothed;

    final goal = _centerFor(
      LatLng(target.latitude, target.longitude),
      rotation,
    );
    final center = _followCenter(_easedCenter(goal, now), now, speedMps);

    final rotationChanged =
        _angleDelta(rotation, camera.rotation).abs() > _rotationEpsilon;
    if (center != camera.center || rotationChanged) {
      _map.moveAndRotate(center, camera.zoom, rotation);
    }
  }

  /// How long until following may resume; zero when not paused.
  Duration timeUntilResume(Duration now) {
    final paused = _pausedAt;
    if (paused == null) return Duration.zero;
    final remaining = resumeAfter - (now - paused);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// The map center that puts [rider] at [_riderHeightFraction] of the screen
  /// height when the map is rotated by [rotationDegrees].
  LatLng _centerFor(LatLng rider, double rotationDegrees) {
    final camera = _map.camera;
    // Only the part of the map above the bottom panel counts as visible, so
    // the rider stays clear of the panel however far it is opened.
    final height = camera.nonRotatedSize.height;
    final visible = math.max(height - bottomInset, height / 2);
    final below = visible * _riderHeightFraction - height / 2;
    final theta = rotationDegrees * math.pi / 180;
    // The screen offset (0, below) expressed in unrotated map pixels.
    final worldOffset = Offset(
      below * math.sin(theta),
      below * math.cos(theta),
    );
    final riderPixels = camera.projectAtZoom(rider, camera.zoom);
    return camera.unprojectAtZoom(riderPixels - worldOffset, camera.zoom);
  }

  /// [goal], eased in from where the camera was when following resumed.
  LatLng _easedCenter(LatLng goal, Duration now) {
    final from = _returnFrom;
    final start = _returnStart;
    if (from == null || start == null) return goal;
    final t = (now - start).inMicroseconds / _returnDuration.inMicroseconds;
    if (t >= 1) {
      _returnFrom = null;
      _returnStart = null;
      return goal;
    }
    final eased = AppMotion.curve.transform(t);
    return LatLng(
      from.latitude + (goal.latitude - from.latitude) * eased,
      from.longitude + (goal.longitude - from.longitude) * eased,
    );
  }

  /// The camera centre this frame: [goal] seen through a light, velocity-aware
  /// low-pass filter.
  ///
  /// The marker it follows already glides, but every tiny correction in it
  /// would otherwise reach the whole map at once and read as jitter. The
  /// filter absorbs those. Its time constant shrinks as speed rises, so the
  /// rider stays put on screen at speed (lag in metres is speed × time
  /// constant) while slow riding and standing still stay calm. Very large
  /// moves, or the first frame, snap rather than drag across the map.
  LatLng _followCenter(LatLng goal, Duration now, double speedMps) {
    final previous = _smoothed;
    final last = _smoothedAt;
    _smoothedAt = now;
    if (previous == null || last == null || _returnStart != null) {
      return _smoothed = goal;
    }
    final camera = _map.camera;
    final from = camera.projectAtZoom(previous, camera.zoom);
    final to = camera.projectAtZoom(goal, camera.zoom);
    final gap = to - from;
    if (gap.distance > _snapPixels) return _smoothed = goal;

    final dt = (now - last).inMicroseconds / Duration.microsecondsPerSecond;
    final speedFactor = (speedMps / _fastSpeedMps).clamp(0.0, 1.0);
    final tau =
        _slowTimeConstant +
        (_fastTimeConstant - _slowTimeConstant) * speedFactor;
    final alpha = 1 - math.exp(-dt / tau);
    _lagPixels = gap.distance * (1 - alpha);
    return _smoothed = camera.unprojectAtZoom(from + gap * alpha, camera.zoom);
  }

  LatLng? _smoothed;
  Duration? _smoothedAt;

  /// How far the filtered centre still trails its goal, in screen pixels.
  double _lagPixels = 0;

  /// Time constants of the follow filter at rest and at [_fastSpeedMps].
  static const double _slowTimeConstant = 0.32;
  static const double _fastTimeConstant = 0.12;
  static const double _fastSpeedMps = 20;

  /// The filter stops easing once the camera is this close to its goal.
  static const double _settledPixels = 0.3;

  /// A jump bigger than this (a GPS reset, a resize) is taken at once.
  static const double _snapPixels = 400;

  bool _shouldResume(Duration now) {
    final paused = _pausedAt;
    return paused != null && now - paused >= resumeAfter;
  }

  /// Signed shortest difference between two angles, in (-180, 180].
  static double _angleDelta(double a, double b) => ((a - b + 540) % 360) - 180;
}
