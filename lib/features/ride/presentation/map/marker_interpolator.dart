import 'dart:math' as math;
import 'dart:ui';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/geo_point.dart';

/// Where a rider should be drawn, as reported by the latest data.
class MarkerTarget {
  const MarkerTarget({
    required this.uid,
    required this.point,
    required this.color,
    required this.headingDegrees,
    required this.isMe,
    this.speedMps,
  });

  final String uid;
  final GeoPoint point;
  final Color color;

  /// Direction of travel to draw, or `null` to draw none. Also gates
  /// prediction: a rider with no heading is treated as standing still.
  final double? headingDegrees;
  final bool isMe;

  /// Ground speed at [point], when known; used to predict movement between
  /// updates.
  final double? speedMps;
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
    this.scale = 1,
    this.pulse,
    this.float = 0,
  });

  final String uid;
  final GeoPoint point;
  final Color color;
  final double? headingDegrees;

  /// 0–1; fades riders in when they appear and out when they leave.
  final double opacity;
  final bool isMe;

  /// Size of the marker relative to rest: springs up from small on arrival,
  /// shrinks away on departure.
  final double scale;

  /// Progress (0–1) of a soft ring expanding from the marker, or `null` when
  /// none is showing. Plays once as a rider arrives and then every few
  /// seconds while they are on the map.
  final double? pulse;

  /// The idle float, -1 to 1: a slow, tiny drift that keeps a resting marker
  /// from looking frozen.
  final double float;
}

/// Turns discrete GPS updates into continuous motion.
///
/// Every rider is drawn on a predicted path: from their latest report, along
/// their heading at their speed (dead reckoning). When a new report arrives
/// the marker does not jump to it; it blends from the path it was on to the
/// new one over about the time between reports. So a moving rider glides
/// steadily instead of moving, pausing and moving again, and a correction is
/// spread over a second rather than shown as a jump.
///
/// Prediction runs linearly for [_predictLinear] past a report, then eases to
/// a stop over a further [_predictDecay], so a rider whose updates stop (a
/// lost signal, a sudden stop) drifts only a few metres before settling.
///
/// Arrivals fade in, spring up from small and send out one soft ring;
/// departures fade and shrink away. Pure timing logic, driven by the caller's
/// clock, so it costs a few multiplications per rider per frame.
class MarkerInterpolator {
  final Map<String, _Track> _tracks = {};

  static const Duration _minGlide = Duration(milliseconds: 250);
  static const Duration _maxGlide = Duration(milliseconds: 1600);

  /// Arrival and departure fades.
  static const Duration _fade = Duration(milliseconds: 450);

  /// When the arrival ring starts, after the marker has popped in.
  static const Duration _joinPulseDelay = Duration(milliseconds: 350);

  /// How long one ring takes to expand and fade.
  static const Duration _pulseLength = Duration(milliseconds: 1100);

  /// How often a resting ring repeats.
  static const Duration _pulseEvery = Duration(seconds: 4);

  /// One full idle float.
  static const Duration _floatPeriod = Duration(milliseconds: 3200);

  /// How far ahead of a report movement is predicted at full speed, and how
  /// long it then takes to ease to a stop.
  static const Duration _predictLinear = Duration(milliseconds: 1200);
  static const Duration _predictDecay = Duration(milliseconds: 600);

  /// Size of an arriving marker before it springs up, and of a departing one
  /// as it vanishes.
  static const double _arriveScale = 0.4;
  static const double _leaveScale = 0.6;

  /// A jump this large is a GPS reset, not movement: snap instead of gliding
  /// across the map.
  static const double _teleportMeters = 2000;

  /// Applies the latest [targets]; riders missing from it fade out.
  ///
  /// Only riders whose position or heading actually changed are touched;
  /// everyone else keeps gliding undisturbed.
  void update(Iterable<MarkerTarget> targets, Duration now) {
    final seen = <String>{};
    for (final target in targets) {
      seen.add(target.uid);
      final track = _tracks[target.uid];
      if (track == null || track.leaving) {
        _tracks[target.uid] = _Track.arrive(target, now, track);
      } else if (!track.target.point.samePlaceAs(target.point) ||
          track.target.headingDegrees != target.headingDegrees) {
        track.retarget(target, now);
      } else {
        // Same position: keep the current path; just refresh styling.
        track.target = target;
      }
    }
    for (final entry in _tracks.entries) {
      if (!seen.contains(entry.key)) entry.value.leave(now);
    }
  }

  /// Whether any marker is moving, predicting, arriving or leaving at [now].
  /// The idle float and pulse are not counted; see [hasMarkers].
  bool isAnimating(Duration now) =>
      _tracks.values.any((track) => track.isAnimating(now));

  /// Whether there are markers on the map, which keeps the idle float and
  /// pulse running.
  bool get hasMarkers => _tracks.isNotEmpty;

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

  /// One rider's predicted ground speed at [now], in m/s; zero when unknown
  /// or standing still. The follow camera uses it to tune how closely it
  /// tracks.
  double speedOf(String uid, Duration now) => _tracks[uid]?.speedAt(now) ?? 0;

  static double _progress(Duration now, Duration start, Duration length) {
    if (length <= Duration.zero) return 1;
    final t = (now - start).inMicroseconds / length.inMicroseconds;
    return t.clamp(0.0, 1.0);
  }

  /// Seconds of travel predicted [sinceReport] after a report: linear at
  /// first, then easing to a stop.
  static double _predictedSeconds(Duration sinceReport) {
    double seconds(Duration d) =>
        d.inMicroseconds / Duration.microsecondsPerSecond;
    final s = seconds(sinceReport);
    if (s <= 0) return 0;
    final linear = seconds(_predictLinear);
    final decay = seconds(_predictDecay);
    if (s <= linear) return s;
    return linear + decay * (1 - math.exp(-(s - linear) / decay));
  }
}

/// One straight-line motion: a start point, a heading and a speed, from a
/// moment in time.
class _Path {
  const _Path(this.origin, this.at, this.headingDegrees, this.speedMps);

  /// A path that stays put at [point].
  const _Path.still(GeoPoint point, Duration at) : this(point, at, null, 0);

  final GeoPoint origin;
  final Duration at;
  final double? headingDegrees;
  final double speedMps;

  bool get moves => headingDegrees != null && speedMps > 0;

  GeoPoint positionAt(Duration now) {
    if (!moves) return origin;
    final seconds = MarkerInterpolator._predictedSeconds(now - at);
    return origin.offsetBy(speedMps * seconds, headingDegrees!);
  }

  /// Speed along the path at [now]; falls off as prediction eases to a stop.
  double speedAt(Duration now) {
    if (!moves) return 0;
    final since = now - at;
    if (since <= MarkerInterpolator._predictLinear) return speedMps;
    final over =
        (since - MarkerInterpolator._predictLinear).inMicroseconds /
        MarkerInterpolator._predictDecay.inMicroseconds;
    return speedMps * math.exp(-over);
  }

  /// Whether the drawn point is still noticeably moving along this path.
  bool isMoving(Duration now) =>
      moves &&
      now - at <
          MarkerInterpolator._predictLinear +
              MarkerInterpolator._predictDecay * 4;
}

class _Track {
  _Track._(this.target, Duration now, this.phaseMs)
    : current = _pathFor(target, now),
      previous = _Path.still(target.point, now),
      blendStart = now,
      blend = Duration.zero,
      lastUpdate = now,
      arrivedAt = now,
      fadeStart = now,
      fromHeading = target.headingDegrees;

  /// A rider appearing; if they were fading out, they come back from where
  /// they are.
  factory _Track.arrive(MarkerTarget target, Duration now, _Track? leaving) {
    final track = _Track._(target, now, _phaseFor(target.uid));
    if (leaving != null) {
      track
        ..fromOpacity = leaving._opacityAt(now)
        ..previous = _Path.still(leaving.positionAt(now), now)
        ..blend = MarkerInterpolator._minGlide
        // Already on screen: no second pop and ring.
        ..arrivedAt = now - MarkerInterpolator._pulseLength * 2;
    }
    return track;
  }

  MarkerTarget target;

  /// The path the latest report puts the rider on.
  _Path current;

  /// The path the marker was on before the latest report; blended out over
  /// [blend].
  _Path previous;
  Duration blendStart;
  Duration blend;
  Duration lastUpdate;
  Duration arrivedAt;
  Duration fadeStart;
  double fromOpacity = 0;
  double toOpacity = 1;
  double? fromHeading;
  bool leaving = false;

  /// Offsets this rider's idle float and pulse, so a group never breathes in
  /// unison.
  final int phaseMs;

  static _Path _pathFor(MarkerTarget target, Duration now) => _Path(
    target.point,
    now,
    target.headingDegrees,
    target.headingDegrees == null ? 0 : (target.speedMps ?? 0),
  );

  static int _phaseFor(String uid) =>
      uid.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff) %
      MarkerInterpolator._pulseEvery.inMilliseconds;

  void retarget(MarkerTarget next, Duration now) {
    final drawn = positionAt(now);
    fromHeading = headingAt(now);
    final sinceLast = now - lastUpdate;
    lastUpdate = now;
    blendStart = now;
    final nextPath = _pathFor(next, now);
    if (drawn.distanceMetersTo(next.point) >
        MarkerInterpolator._teleportMeters) {
      previous = nextPath;
      blend = Duration.zero;
    } else {
      // Carry on along the path being drawn, unless the rider has stopped:
      // then glide straight to where they stopped, without overshooting.
      final keepGoing = nextPath.moves ? speedAt(now) : 0.0;
      previous = _Path(drawn, now, fromHeading, keepGoing);
      blend = _clamp(sinceLast);
    }
    current = nextPath;
    target = next;
  }

  void leave(Duration now) {
    if (leaving) return;
    leaving = true;
    fromOpacity = _opacityAt(now);
    toOpacity = 0;
    fadeStart = now;
  }

  double _blendAt(Duration now) => AppMotion.move.transform(
    MarkerInterpolator._progress(now, blendStart, blend),
  );

  bool isAnimating(Duration now) =>
      now - blendStart < blend ||
      now - fadeStart < MarkerInterpolator._fade ||
      now - arrivedAt <
          MarkerInterpolator._joinPulseDelay +
              MarkerInterpolator._pulseLength ||
      current.isMoving(now);

  bool isGone(Duration now) =>
      leaving && now - fadeStart >= MarkerInterpolator._fade;

  GeoPoint positionAt(Duration now) {
    final to = current.positionAt(now);
    final t = _blendAt(now);
    if (t >= 1) return to;
    final from = previous.positionAt(now);
    return GeoPoint(
      latitude: from.latitude + (to.latitude - from.latitude) * t,
      longitude: from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  double speedAt(Duration now) {
    final t = _blendAt(now);
    final to = current.speedAt(now);
    return t >= 1 ? to : previous.speedAt(now) * (1 - t) + to * t;
  }

  double? headingAt(Duration now) {
    final to = target.headingDegrees;
    final start = fromHeading;
    if (to == null || start == null) return to;
    final t = _blendAt(now);
    // Turn the short way round, e.g. 350° → 10° passes through north.
    final delta = ((to - start + 540) % 360) - 180;
    return (start + delta * t + 360) % 360;
  }

  double _opacityAt(Duration now) {
    final t = AppMotion.curve.transform(
      MarkerInterpolator._progress(now, fadeStart, MarkerInterpolator._fade),
    );
    return fromOpacity + (toOpacity - fromOpacity) * t;
  }

  double _scaleAt(Duration now) {
    if (leaving) {
      final t = AppMotion.exit.transform(
        MarkerInterpolator._progress(now, fadeStart, MarkerInterpolator._fade),
      );
      return 1 - (1 - MarkerInterpolator._leaveScale) * t;
    }
    final t = MarkerInterpolator._progress(
      now,
      arrivedAt,
      AppMotion.springDuration,
    );
    if (t >= 1) return 1;
    const from = MarkerInterpolator._arriveScale;
    return from + (1 - from) * AppMotion.spring.transform(t);
  }

  double? _pulseAt(Duration now) {
    if (leaving) return null;
    final sinceJoin = now - arrivedAt - MarkerInterpolator._joinPulseDelay;
    const length = MarkerInterpolator._pulseLength;
    if (sinceJoin < Duration.zero) return null;
    if (sinceJoin < length) {
      return sinceJoin.inMicroseconds / length.inMicroseconds;
    }
    final every = MarkerInterpolator._pulseEvery.inMilliseconds;
    final cycle = (now.inMilliseconds + phaseMs) % every;
    final lengthMs = length.inMilliseconds;
    return cycle < lengthMs ? cycle / lengthMs : null;
  }

  double _floatAt(Duration now) {
    final period = MarkerInterpolator._floatPeriod.inMilliseconds;
    final phase = ((now.inMilliseconds + phaseMs) % period) / period;
    return math.sin(phase * 2 * math.pi);
  }

  MarkerFrame frameAt(Duration now) => MarkerFrame(
    uid: target.uid,
    point: positionAt(now),
    color: target.color,
    headingDegrees: headingAt(now),
    opacity: _opacityAt(now),
    isMe: target.isMe,
    scale: _scaleAt(now),
    pulse: _pulseAt(now),
    float: _floatAt(now),
  );

  static Duration _clamp(Duration value) {
    if (value < MarkerInterpolator._minGlide) {
      return MarkerInterpolator._minGlide;
    }
    if (value > MarkerInterpolator._maxGlide) {
      return MarkerInterpolator._maxGlide;
    }
    return value;
  }
}
