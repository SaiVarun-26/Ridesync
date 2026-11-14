import 'dart:math' as math;

import '../../../ride/domain/geo_point.dart';

/// The overall shape a route made.
enum RouteShape {
  loop('Loop', 'Finished back where it started'),
  outAndBack('Out and back', 'Rode out and returned the same way'),
  pointToPoint('Point to point', 'Finished somewhere new');

  const RouteShape(this.label, this.description);

  final String label;
  final String description;
}

/// How much a route twisted, from the heading change per kilometre.
enum Twistiness {
  straight('Mostly straight'),
  gentle('Gentle curves'),
  winding('Winding'),
  twisty('Very twisty');

  const Twistiness(this.label);

  final String label;
}

/// A rough guess at the kind of riding a route was. Rule-based, from how
/// often it turned and how fast it went, so it is labelled as an estimate.
enum RouteCharacter {
  city('City streets'),
  winding('Winding, scenic roads'),
  openRoad('Open road'),
  mixed('Mixed roads');

  const RouteCharacter(this.label);

  final String label;
}

/// How demanding a ride was.
enum RideIntensity {
  easy('Easy'),
  moderate('Moderate'),
  high('High'),
  intense('Intense');

  const RideIntensity(this.label);

  final String label;

  static RideIntensity fromScore(double score) => switch (score) {
    < 30 => easy,
    < 55 => moderate,
    < 78 => high,
    _ => intense,
  };
}

/// Route-level facts about a finished ride.
class RouteProfile {
  const RouteProfile({
    required this.distanceMeters,
    required this.turnCount,
    required this.degreesPerKm,
    required this.longestStraightMeters,
    required this.shape,
    required this.character,
    required this.intensityScore,
  });

  final double distanceMeters;

  /// Real turns: about 45° or more within a short distance, at corners and
  /// junctions, not the gentle bends of a road.
  final int turnCount;

  /// Total change of direction per kilometre, ignoring GPS wobble.
  final double degreesPerKm;

  /// The longest stretch that held one direction.
  final double longestStraightMeters;

  final RouteShape shape;
  final RouteCharacter character;

  /// 0–100: speed, turns and stopping combined.
  final double intensityScore;

  double get turnsPerKm =>
      distanceMeters > 0 ? turnCount / (distanceMeters / 1000) : 0;

  Twistiness get twistiness => switch (degreesPerKm) {
    < 60 => Twistiness.straight,
    < 140 => Twistiness.gentle,
    < 260 => Twistiness.winding,
    _ => Twistiness.twisty,
  };

  RideIntensity get intensity => RideIntensity.fromScore(intensityScore);
}

/// Analyses a recorded route's geometry. Pure and bounded: the route is
/// resampled to evenly spaced points (at most [_maxSamples]) first, so the
/// cost does not depend on how densely it was recorded.
abstract final class RouteAnalyzer {
  /// Spacing of the resampled route. Close to the recording spacing, so no
  /// detail is invented, and long enough to average out GPS wobble.
  static const double _stepMeters = 30;
  static const int _maxSamples = 2000;

  /// Changes of direction below this, between neighbouring samples, are GPS
  /// wobble and are ignored.
  static const double _wobbleDegrees = 4;

  /// A turn is at least this much change of direction within [_turnSpan]
  /// samples; after one, the next is not looked for until [_turnCooldown]
  /// samples on.
  static const double _turnDegrees = 45;
  static const int _turnSpan = 3;
  static const int _turnCooldown = 3;

  /// A straight holds within this many degrees of its starting direction.
  static const double _straightTolerance = 12;

  /// The ride ended within this distance of its start (or this share of its
  /// length, whichever is more) to count as returning.
  static const double _closeMeters = 150;
  static const double _closeShare = 0.06;

  /// Out and back: this share of the way home lies on the way out.
  static const double _overlapMeters = 45;
  static const double _overlapShare = 0.6;
  static const int _overlapSamples = 240;

  /// Speed that counts as fast riding for intensity, in m/s (about 40 km/h).
  static const double _fastMps = 11;

  /// Routes shorter than this tell too little to analyse.
  static const double minRouteMeters = 300;

  /// The profile of [points]. [averageMovingSpeedMps] and [slowdowns], when
  /// known, refine the character and intensity. `null` for a route too short
  /// to say anything about.
  static RouteProfile? analyze(
    List<GeoPoint> points, {
    double? averageMovingSpeedMps,
    int slowdowns = 0,
  }) {
    if (points.length < 3) return null;
    final total = _length(points);
    if (total < minRouteMeters) return null;
    final step = math.max(_stepMeters, total / _maxSamples);
    final samples = _resample(points, step);
    if (samples.length < 4) return null;

    final bearings = [
      for (var i = 0; i < samples.length - 1; i++)
        samples[i].bearingDegreesTo(samples[i + 1]),
    ];
    final turns = [
      for (var i = 0; i < bearings.length - 1; i++)
        _delta(bearings[i], bearings[i + 1]),
    ];

    var absolute = 0.0;
    for (final t in turns) {
      if (t.abs() >= _wobbleDegrees) absolute += t.abs();
    }
    final km = total / 1000;
    final degreesPerKm = absolute / km;

    var turnCount = 0;
    var nextAllowed = 0;
    for (var i = 0; i < turns.length; i++) {
      if (i < nextAllowed) continue;
      var sum = 0.0;
      for (var j = i; j < math.min(turns.length, i + _turnSpan); j++) {
        sum += turns[j];
      }
      if (sum.abs() >= _turnDegrees) {
        turnCount++;
        nextAllowed = i + _turnSpan + _turnCooldown;
      }
    }

    var longest = 0.0;
    var start = 0;
    while (start < bearings.length) {
      var end = start;
      while (end + 1 < bearings.length &&
          _delta(bearings[start], bearings[end + 1]).abs() <=
              _straightTolerance) {
        end++;
      }
      longest = math.max(longest, (end - start + 1) * step);
      start = end + 1;
    }

    final shape = _shape(samples, total);
    final turnsPerKm = turnCount / km;
    final speedKmh = averageMovingSpeedMps == null
        ? null
        : averageMovingSpeedMps * 3.6;
    final character = switch (true) {
      _ when turnsPerKm >= 3 && (speedKmh == null || speedKmh < 28) =>
        RouteCharacter.city,
      _ when degreesPerKm >= 220 && turnsPerKm < 3 => RouteCharacter.winding,
      _
          when turnsPerKm < 1.2 &&
              degreesPerKm < 120 &&
              (speedKmh == null || speedKmh >= 30) =>
        RouteCharacter.openRoad,
      _ => RouteCharacter.mixed,
    };

    final speedPart = averageMovingSpeedMps == null
        ? 0.4
        : (averageMovingSpeedMps / _fastMps).clamp(0.0, 1.0);
    final turnPart = (turnsPerKm / 5).clamp(0.0, 1.0);
    final stopPart = (slowdowns / km / 2).clamp(0.0, 1.0);
    final distancePart = (km / 50).clamp(0.0, 1.0);
    final intensity =
        100 *
        (0.45 * speedPart +
            0.2 * turnPart +
            0.15 * stopPart +
            0.2 * distancePart);

    return RouteProfile(
      distanceMeters: total,
      turnCount: turnCount,
      degreesPerKm: degreesPerKm,
      longestStraightMeters: math.min(longest, total),
      shape: shape,
      character: character,
      intensityScore: intensity,
    );
  }

  static RouteShape _shape(List<GeoPoint> samples, double total) {
    final gap = samples.first.distanceMetersTo(samples.last);
    final returned = gap <= math.max(_closeMeters, total * _closeShare);
    if (!returned) return RouteShape.pointToPoint;

    // Out and back if most of the way home retraces the way out.
    final every = math.max(1, samples.length ~/ _overlapSamples);
    final thin = [for (var i = 0; i < samples.length; i += every) samples[i]];
    final half = thin.length ~/ 2;
    final out = thin.sublist(0, half);
    final back = thin.sublist(half);
    if (out.isEmpty || back.isEmpty) return RouteShape.loop;
    var onTheWayOut = 0;
    for (final p in back) {
      for (final q in out) {
        if (p.distanceMetersTo(q) <= _overlapMeters) {
          onTheWayOut++;
          break;
        }
      }
    }
    return onTheWayOut / back.length >= _overlapShare
        ? RouteShape.outAndBack
        : RouteShape.loop;
  }

  /// Evenly spaced points [step] metres apart along [points].
  static List<GeoPoint> _resample(List<GeoPoint> points, double step) {
    final result = <GeoPoint>[points.first];
    var carry = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final length = a.distanceMetersTo(b);
      if (length <= 0) continue;
      var at = step - carry;
      while (at <= length) {
        final t = at / length;
        result.add(
          GeoPoint(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t,
          ),
        );
        at += step;
      }
      carry = length - (at - step);
    }
    return result;
  }

  static double _length(List<GeoPoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += points[i - 1].distanceMetersTo(points[i]);
    }
    return total;
  }

  /// Signed shortest turn from bearing [a] to bearing [b], in (-180, 180].
  static double _delta(double a, double b) => ((b - a + 540) % 360) - 180;
}
