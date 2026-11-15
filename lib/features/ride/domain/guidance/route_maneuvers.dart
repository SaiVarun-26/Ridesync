import '../geo_point.dart';
import 'route_geometry.dart';

/// What the rider does at a point on the route.
enum ManeuverKind {
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  arrive;

  bool get isLeft => this == slightLeft || this == left || this == sharpLeft;

  /// A short instruction, e.g. "Turn left".
  String get instruction => switch (this) {
    slightLeft => 'Bear left',
    left => 'Turn left',
    sharpLeft => 'Sharp left',
    slightRight => 'Bear right',
    right => 'Turn right',
    sharpRight => 'Sharp right',
    uTurn => 'Make a U-turn',
    arrive => 'Arrive',
  };

  /// The same, lower case, for "then turn left".
  String get thenPhrase => switch (this) {
    arrive => 'then arrive',
    _ => 'then ${instruction[0].toLowerCase()}${instruction.substring(1)}',
  };
}

/// One turn (or the arrival) along a route.
class RouteManeuver {
  const RouteManeuver({
    required this.kind,
    required this.alongMeters,
    required this.point,
    this.turnDegrees = 0,
  });

  final ManeuverKind kind;

  /// Where it happens, measured from the start along the route.
  final double alongMeters;
  final GeoPoint point;

  /// Signed change of direction: positive turns right, negative left.
  final double turnDegrees;
}

/// Finds the turns in a route from its shape alone.
///
/// The planned route is stored as geometry only, so turns are read from it:
/// the direction of travel is compared a short way before and after every
/// vertex. Sharp changes are turns; the long, gentle bends of an open road are
/// not, so a winding road does not spam the rider with cues. Neighbouring
/// candidates (a corner drawn with several points, a small roundabout) are
/// merged into the strongest one. Pure Dart; runs once per route.
abstract final class ManeuverDetector {
  /// How far before and after a vertex the direction is measured.
  static const double windowMeters = 22;

  /// Direction changes below this are bends, not turns.
  static const double minTurnDegrees = 40;

  /// Candidates closer together than this are one manoeuvre.
  static const double mergeMeters = 35;

  /// Turns this close to the start or the end are not worth announcing.
  static const double edgeMeters = 15;

  static List<RouteManeuver> detect(RouteGeometry route) {
    if (!route.isUsable) return const [];
    final total = route.lengthMeters;
    final result = <RouteManeuver>[];
    RouteManeuver? pending;

    void flush() {
      final p = pending;
      if (p != null) result.add(p);
      pending = null;
    }

    for (var i = 1; i < route.length - 1; i++) {
      final along = route.alongAt(i);
      if (along < edgeMeters || along > total - edgeMeters) continue;
      final inBearing = route.bearingBetween(along - windowMeters, along);
      final outBearing = route.bearingBetween(along, along + windowMeters);
      final delta = _signedDelta(outBearing, inBearing);
      if (delta.abs() < minTurnDegrees) {
        final p = pending;
        if (p != null && along - p.alongMeters > mergeMeters) flush();
        continue;
      }
      final candidate = RouteManeuver(
        kind: _classify(delta),
        alongMeters: along,
        point: route.points[i],
        turnDegrees: delta,
      );
      final p = pending;
      if (p == null) {
        pending = candidate;
      } else if (along - p.alongMeters <= mergeMeters) {
        if (delta.abs() > p.turnDegrees.abs()) pending = candidate;
      } else {
        flush();
        pending = candidate;
      }
    }
    flush();
    result.add(
      RouteManeuver(
        kind: ManeuverKind.arrive,
        alongMeters: total,
        point: route.end,
      ),
    );
    return List.unmodifiable(result);
  }

  static ManeuverKind _classify(double delta) {
    final a = delta.abs();
    final right = delta > 0;
    if (a >= 160) return ManeuverKind.uTurn;
    if (a >= 130) return right ? ManeuverKind.sharpRight : ManeuverKind.sharpLeft;
    if (a >= 60) return right ? ManeuverKind.right : ManeuverKind.left;
    return right ? ManeuverKind.slightRight : ManeuverKind.slightLeft;
  }

  /// Signed shortest rotation from [from] to [to], in (-180, 180].
  static double _signedDelta(double to, double from) =>
      ((to - from + 540) % 360) - 180;
}
