import 'dart:ui';

import '../../domain/geo_point.dart';

/// Where a rider should be drawn, as reported by the latest data.
class MarkerTarget {
  const MarkerTarget({
    required this.uid,
    required this.point,
    required this.color,
    required this.headingDegrees,
    required this.isMe,
  });

  final String uid;
  final GeoPoint point;
  final Color color;

  /// Direction of travel to draw, or `null` to draw none.
  final double? headingDegrees;
  final bool isMe;
}

/// A rider's interpolated state for one frame.
class MarkerFrame {
  const MarkerFrame({
    required this.uid,
    required this.point,
    required this.color,
    required this.headingDegrees,
    required this.opacity,
    required this.isMe,
  });

  final String uid;
  final GeoPoint point;
  final Color color;
  final double? headingDegrees;

  /// 0–1; fades riders in when they appear and out when they leave.
  final double opacity;
  final bool isMe;
}

/// Turns discrete GPS updates into continuous motion.
///
/// Each new position starts a glide from wherever the marker is drawn right
/// now, lasting about as long as the gap since the previous update. Riders
/// therefore move at a steady speed and never jump. Arrivals fade in and
/// departures fade out. Pure timing logic, driven by the caller's clock.
class MarkerInterpolator {
  final Map<String, _Track> _tracks = {};

  static const Duration _minGlide = Duration(milliseconds: 250);
  static const Duration _maxGlide = Duration(milliseconds: 1600);
  static const Duration _fade = Duration(milliseconds: 450);

  /// A jump this large is a GPS reset, not movement: snap instead of gliding
  /// across the map.
  static const double _teleportMeters = 2000;

  /// Applies the latest [targets]; riders missing from it fade out.
  void update(Iterable<MarkerTarget> targets, Duration now) {
    final seen = <String>{};
    for (final target in targets) {
      seen.add(target.uid);
      final track = _tracks[target.uid];
      if (track == null || track.leaving) {
        _tracks[target.uid] = _Track.arrive(target, now, track);
      } else if (track.target.point != target.point ||
          track.target.headingDegrees != target.headingDegrees) {
        track.retarget(target, now);
      } else {
        // Same position: keep the current glide; just refresh styling.
        track.target = target;
      }
    }
    for (final entry in _tracks.entries) {
      if (!seen.contains(entry.key)) entry.value.leave(now);
    }
  }

  /// Whether anything is still moving or fading at [now].
  bool isAnimating(Duration now) =>
      _tracks.values.any((track) => track.isAnimating(now));

  /// Every visible rider's state at [now]. Fully faded riders are dropped.
  List<MarkerFrame> sample(Duration now) {
    _tracks.removeWhere((_, track) => track.isGone(now));
    return [for (final track in _tracks.values) track.frameAt(now)];
  }

  /// One rider's drawn position at [now], if visible.
  GeoPoint? positionOf(String uid, Duration now) =>
      _tracks[uid]?.positionAt(now);

  /// One rider's drawn direction of travel at [now]. `null` while they are not
  /// moving, which is how the camera knows to hold its rotation.
  double? headingOf(String uid, Duration now) => _tracks[uid]?.headingAt(now);

  static double _progress(Duration now, Duration start, Duration length) {
    if (length <= Duration.zero) return 1;
    final t = (now - start).inMicroseconds / length.inMicroseconds;
    return t.clamp(0.0, 1.0);
  }
}

class _Track {
  _Track._(this.target, this.from, this.glideStart, this.lastUpdate)
      : glide = Duration.zero,
        fadeStart = lastUpdate,
        fromOpacity = 0,
        toOpacity = 1,
        fromHeading = target.headingDegrees;

  /// A rider appearing; if they were fading out, they fade back in from where
  /// they are.
  factory _Track.arrive(MarkerTarget target, Duration now, _Track? leaving) {
    final track = _Track._(target, target.point, now, now);
    if (leaving != null) {
      track.fromOpacity = leaving._opacityAt(now);
      track.from = leaving.positionAt(now);
      track.glide = MarkerInterpolator._minGlide;
    }
    return track;
  }

  MarkerTarget target;
  GeoPoint from;
  Duration glideStart;
  Duration glide;
  Duration lastUpdate;
  Duration fadeStart;
  double fromOpacity;
  double toOpacity;
  double? fromHeading;
  bool leaving = false;

  void retarget(MarkerTarget next, Duration now) {
    final current = positionAt(now);
    fromHeading = headingAt(now);
    final sinceLast = now - lastUpdate;
    lastUpdate = now;
    glideStart = now;
    final distance = current.distanceMetersTo(next.point);
    if (distance > MarkerInterpolator._teleportMeters) {
      from = next.point;
      glide = Duration.zero;
    } else {
      from = current;
      glide = _clamp(sinceLast);
    }
    target = next;
  }

  void leave(Duration now) {
    if (leaving) return;
    leaving = true;
    fromOpacity = _opacityAt(now);
    toOpacity = 0;
    fadeStart = now;
  }

  bool isAnimating(Duration now) =>
      now - glideStart < glide || now - fadeStart < MarkerInterpolator._fade;

  bool isGone(Duration now) =>
      leaving && now - fadeStart >= MarkerInterpolator._fade;

  GeoPoint positionAt(Duration now) {
    final t = MarkerInterpolator._progress(now, glideStart, glide);
    final to = target.point;
    return GeoPoint(
      latitude: from.latitude + (to.latitude - from.latitude) * t,
      longitude: from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  double? headingAt(Duration now) {
    final to = target.headingDegrees;
    final start = fromHeading;
    if (to == null || start == null) return to;
    final t = MarkerInterpolator._progress(now, glideStart, glide);
    // Turn the short way round, e.g. 350° → 10° passes through north.
    final delta = ((to - start + 540) % 360) - 180;
    return (start + delta * t + 360) % 360;
  }

  double _opacityAt(Duration now) {
    final t =
        MarkerInterpolator._progress(now, fadeStart, MarkerInterpolator._fade);
    return fromOpacity + (toOpacity - fromOpacity) * t;
  }

  MarkerFrame frameAt(Duration now) => MarkerFrame(
        uid: target.uid,
        point: positionAt(now),
        color: target.color,
        headingDegrees: headingAt(now),
        opacity: _opacityAt(now),
        isMe: target.isMe,
      );

  static Duration _clamp(Duration value) {
    if (value < MarkerInterpolator._minGlide) return MarkerInterpolator._minGlide;
    if (value > MarkerInterpolator._maxGlide) return MarkerInterpolator._maxGlide;
    return value;
  }
}
