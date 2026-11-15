import 'dart:math' as math;

import '../geo_point.dart';
import '../guidance/route_geometry.dart';
import 'ride_format.dart';

/// Where another rider is, relative to this one.
enum RelativeDirection {
  /// Further along the path than this rider.
  ahead,

  /// Not as far along the path as this rider.
  behind,

  /// Side by side: too close for ahead or behind to mean anything.
  nearby,

  /// No path and no direction of travel to judge by (a rider who has not
  /// moved yet): only the distance is shown.
  unknown,
}

/// One rider's position relative to this rider: how far away they are right
/// now, and whether they are ahead, behind or nearby.
///
/// The answer comes from the two riders' current GPS positions alone. Both
/// are placed on the same path, and whoever is further along that path is
/// ahead. Nothing about the ride's bookkeeping takes part: not who is the
/// host, not who joined first, not how far either rider has ridden in total.
///
/// Which path is used, in order of preference:
/// 1. The planned route of a guided ride, when both riders are on it.
/// 2. This rider's own ridden trail, extended straight on past its end, when
///    both riders sit on it. Someone behind is on the trail; someone ahead is
///    on its continuation.
/// 3. The other rider's trail, the same way round.
/// 4. With no shared path (different roads, no trail yet), this rider's
///    direction of travel: ahead is the half-plane in front of them.
class RelativePosition {
  const RelativePosition({
    required this.meters,
    required this.direction,
    this.source = RelativeSource.none,
  });

  /// How far apart the riders are: along the shared path when there is one
  /// (never less than the straight line), else the straight line.
  final double meters;
  final RelativeDirection direction;

  /// What the answer was based on.
  final RelativeSource source;

  /// Riders closer than this along the path (or in a straight line) are
  /// [RelativeDirection.nearby].
  static const double nearbyMeters = 15;

  /// A rider already nearby stays nearby until the gap passes this, so the
  /// word does not flicker as two riders drift past each other.
  static const double nearbyExitMeters = 25;

  /// A rider further than this from a path is not on it.
  static const double onPathMeters = 40;

  /// Longest stretch of a rider's trail used as a path. Older ground adds
  /// nothing and could cross the present road twice.
  static const double maxTrailMeters = 3000;

  /// Fewest points a trail needs to count as a path.
  static const int minPathPoints = 3;

  /// A trail shorter than this has no reliable direction.
  static const double minPathMeters = 12;

  /// Works out where [other] is relative to [me].
  ///
  /// [myTrail] and [theirTrail] are each rider's recent ridden path, oldest
  /// first, ending at or near their current position. [route] is the guided
  /// ride's planned line, if any. [myHeadingDegrees] and [theirHeadingDegrees]
  /// are directions of travel while moving, `null` while stopped. [previous]
  /// is the last answer for this rider, which keeps "nearby" from flickering.
  factory RelativePosition.between({
    required GeoPoint me,
    required GeoPoint other,
    RouteGeometry? route,
    List<GeoPoint> myTrail = const [],
    List<GeoPoint> theirTrail = const [],
    double? myHeadingDegrees,
    double? theirHeadingDegrees,
    RelativeDirection? previous,
  }) {
    final straight = me.distanceMetersTo(other);
    final nearby = previous == RelativeDirection.nearby
        ? nearbyExitMeters
        : nearbyMeters;

    // Side by side in a straight line: no path can say more.
    if (straight < nearbyMeters) {
      return RelativePosition(
        meters: straight,
        direction: RelativeDirection.nearby,
        source: RelativeSource.distance,
      );
    }

    final candidates = <_Candidate>[];
    if (route != null && route.isUsable) {
      final c = _measure(route, me, other, RelativeSource.route);
      if (c != null) candidates.add(c);
    }
    final mine = _trailGeometry(myTrail, me);
    if (mine != null) {
      final c = _measure(mine, me, other, RelativeSource.myTrail);
      if (c != null) candidates.add(c);
    }
    final theirs = _trailGeometry(theirTrail, other);
    if (theirs != null) {
      final c = _measure(theirs, me, other, RelativeSource.theirTrail);
      if (c != null) candidates.add(c);
    }

    if (candidates.isNotEmpty) {
      // The planned route wins when both are on it; otherwise whichever path
      // both riders sit closest to.
      final best = candidates.first.source == RelativeSource.route
          ? candidates.first
          : candidates.reduce((a, b) => a.worstOffset <= b.worstOffset ? a : b);
      final gap = best.gap;
      final meters = math.max(gap.abs(), straight);
      if (gap.abs() < nearby) {
        return RelativePosition(
          meters: meters,
          direction: RelativeDirection.nearby,
          source: best.source,
        );
      }
      return RelativePosition(
        meters: meters,
        direction: gap > 0 ? RelativeDirection.ahead : RelativeDirection.behind,
        source: best.source,
      );
    }

    return _fromCourse(
      me,
      other,
      straight,
      nearby,
      _course(myTrail, myHeadingDegrees),
      _course(theirTrail, theirHeadingDegrees),
    );
  }

  /// Both riders placed on [path]; `null` when either is off it.
  static _Candidate? _measure(
    RouteGeometry path,
    GeoPoint me,
    GeoPoint other,
    RelativeSource source,
  ) {
    final a = path.projectExtended(me);
    final b = path.projectExtended(other);
    if (a.offsetMeters > onPathMeters || b.offsetMeters > onPathMeters) {
      return null;
    }
    return _Candidate(
      source: source,
      gap: b.alongMeters - a.alongMeters,
      worstOffset: math.max(a.offsetMeters, b.offsetMeters),
    );
  }

  /// A rider's recent trail as a measurable line ending at [now], or `null`
  /// when there is too little of it.
  static RouteGeometry? _trailGeometry(List<GeoPoint> trail, GeoPoint now) {
    if (trail.length < minPathPoints - 1) return null;
    // Walk back from the newest point, keeping up to [maxTrailMeters].
    final kept = <GeoPoint>[now];
    var meters = 0.0;
    for (var i = trail.length - 1; i >= 0; i--) {
      meters += kept.last.distanceMetersTo(trail[i]);
      if (meters > maxTrailMeters) break;
      kept.add(trail[i]);
    }
    if (kept.length < minPathPoints) return null;
    final geometry = RouteGeometry(kept.reversed.toList());
    if (!geometry.isUsable || geometry.lengthMeters < minPathMeters) {
      return null;
    }
    return geometry;
  }

  /// A rider's direction of travel: their heading while moving, else the
  /// direction of the last stretch of their trail.
  static double? _course(List<GeoPoint> trail, double? heading) {
    if (heading != null) return heading;
    if (trail.length < 2) return null;
    final last = trail.last;
    for (var i = trail.length - 2; i >= 0; i--) {
      if (last.distanceMetersTo(trail[i]) >= minPathMeters) {
        return trail[i].bearingDegreesTo(last);
      }
    }
    return null;
  }

  /// No shared path: ahead is in front of this rider's direction of travel.
  /// The other rider's direction is used when this one has none.
  static RelativePosition _fromCourse(
    GeoPoint me,
    GeoPoint other,
    double straight,
    double nearby,
    double? myCourse,
    double? theirCourse,
  ) {
    final course = myCourse ?? theirCourse;
    if (course == null) {
      return RelativePosition(
        meters: straight,
        direction: RelativeDirection.unknown,
        source: RelativeSource.distance,
      );
    }
    final bearing = me.bearingDegreesTo(other);
    // Distance of the other rider along this rider's direction of travel.
    final along = straight * math.cos((bearing - course) * math.pi / 180);
    final direction = along.abs() < nearby
        ? RelativeDirection.nearby
        : along > 0
        ? RelativeDirection.ahead
        : RelativeDirection.behind;
    return RelativePosition(
      meters: straight,
      direction: direction,
      source: RelativeSource.course,
    );
  }

  /// "48 m", "1.2 km".
  String get distanceLabel => RideFormat.distance(meters);

  /// "ahead", "behind", "nearby" or "away".
  String get directionLabel => switch (direction) {
    RelativeDirection.ahead => 'ahead',
    RelativeDirection.behind => 'behind',
    RelativeDirection.nearby => 'nearby',
    RelativeDirection.unknown => 'away',
  };

  /// "48 m ahead", or "Nearby".
  String get label => direction == RelativeDirection.nearby
      ? 'Nearby'
      : '$distanceLabel $directionLabel';
}

/// What a [RelativePosition] was worked out from.
enum RelativeSource { none, route, myTrail, theirTrail, course, distance }

class _Candidate {
  const _Candidate({
    required this.source,
    required this.gap,
    required this.worstOffset,
  });

  final RelativeSource source;

  /// Other rider's place along the path minus this rider's: positive when
  /// the other rider is ahead.
  final double gap;

  /// How far the less well fitting rider is from the path.
  final double worstOffset;
}
