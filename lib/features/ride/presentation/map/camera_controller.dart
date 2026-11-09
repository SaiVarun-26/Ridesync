import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

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

  Duration? _pausedAt;
  Duration? _returnStart;
  LatLng? _returnFrom;

  /// Whether the camera will move this frame (following, or easing back).
  bool isActive(Duration now) => _pausedAt == null || _shouldResume(now);

  /// Whether the camera is still easing at [now]: returning after a pan, or
  /// catching up to a new heading. False while paused, so an idle paused map
  /// renders no frames.
  bool isEasing(Duration now) {
    if (_pausedAt != null) return false;
    final returning =
        _returnStart != null && now - _returnStart! < _returnDuration;
    return returning || _heading.isSettling;
  }

  /// Reports a map event; manual pans pause following and rotating.
  void onMapEvent(MapEvent event, Duration now) {
    if (_panSources.contains(event.source)) {
      _pausedAt = now;
      _returnStart = null;
    }
  }

  /// Moves and rotates the camera for the frame at [now].
  ///
  /// [target] is where this rider is drawn; [headingDegrees] is their drawn
  /// direction of travel, or `null` while stationary.
  void tick(GeoPoint? target, double? headingDegrees, Duration now) {
    if (target == null) return;
    if (_pausedAt != null) {
      if (!_shouldResume(now)) return;
      _pausedAt = null;
      _returnStart = now;
      _returnFrom = _map.camera.center;
    }

    final camera = _map.camera;
    final smoothed = _heading.step(headingDegrees, now);
    // Heading-up: turning the map counter-clockwise by the heading puts the
    // direction of travel at the top of the screen.
    final rotation = smoothed == null ? camera.rotation : -smoothed;

    final goal = _centerFor(LatLng(target.latitude, target.longitude), rotation);
    final center = _easedCenter(goal, now);

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
    final below = camera.nonRotatedSize.height * (_riderHeightFraction - 0.5);
    final theta = rotationDegrees * math.pi / 180;
    // The screen offset (0, below) expressed in unrotated map pixels.
    final worldOffset = Offset(below * math.sin(theta), below * math.cos(theta));
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
    final eased = Curves.easeOutCubic.transform(t);
    return LatLng(
      from.latitude + (goal.latitude - from.latitude) * eased,
      from.longitude + (goal.longitude - from.longitude) * eased,
    );
  }

  bool _shouldResume(Duration now) {
    final paused = _pausedAt;
    return paused != null && now - paused >= resumeAfter;
  }

  /// Signed shortest difference between two angles, in (-180, 180].
  static double _angleDelta(double a, double b) => ((a - b + 540) % 360) - 180;
}
