import 'dart:math' as math;

import '../geo_point.dart';
import '../location_fix.dart';
import 'off_route_detector.dart';
import 'route_geometry.dart';
import 'route_guide.dart';
import 'route_maneuvers.dart';

/// Where the rider stands on the planned route after one fix: everything the
/// guidance UI and the map need, already worked out.
class GuidanceSnapshot {
  const GuidanceSnapshot({
    required this.alongMeters,
    required this.totalMeters,
    required this.offsetMeters,
    required this.isOffRoute,
    required this.hasArrived,
    required this.riderPoint,
    required this.snappedPoint,
    required this.routeBearing,
    required this.activeEndMeters,
    this.next,
    this.afterNext,
    this.rejoinPoint,
    this.remainingTime,
  });

  /// Progress along the route from its start.
  final double alongMeters;
  final double totalMeters;

  /// Straight-line distance from the rider to the route.
  final double offsetMeters;

  final bool isOffRoute;

  /// The rider reached the destination (latched once true).
  final bool hasArrived;

  /// The fix this snapshot was made from.
  final GeoPoint riderPoint;

  /// The nearest point on the route to the rider.
  final GeoPoint snappedPoint;

  /// Direction of the route where the rider is, for a steady camera.
  final double routeBearing;

  /// The highlighted stretch runs from [alongMeters] to here: up to the next
  /// turn, or a little way ahead on a long straight.
  final double activeEndMeters;

  /// The next manoeuvre, and the one after it.
  final RouteManeuver? next;
  final RouteManeuver? afterNext;

  /// Off route only: the closest point ahead on the route to head back to.
  final GeoPoint? rejoinPoint;

  /// Estimated time to the destination, when a speed is known.
  final Duration? remainingTime;

  double get remainingMeters => math.max(0, totalMeters - alongMeters);

  /// Share of the route ridden, 0–1.
  double get fraction =>
      totalMeters <= 0 ? 0 : (alongMeters / totalMeters).clamp(0.0, 1.0);

  /// Distance to the next manoeuvre.
  double? get metersToNext =>
      next == null ? null : math.max(0, next!.alongMeters - alongMeters);

  /// Off route only: straight-line distance back to the route.
  double? get metersToRejoin => rejoinPoint?.distanceMetersTo(riderPoint);

  /// Off route only: compass direction from the rider back to the route.
  double? get rejoinBearing => rejoinPoint == null
      ? null
      : riderPoint.bearingDegreesTo(rejoinPoint!);
}

/// Follows one rider along a [RouteGuide], fix by fix.
///
/// Each fix is matched to the route near where the rider was last time (a
/// short window behind and a longer one ahead), which is both cheap and
/// correct on routes that pass the same street twice. Only when that fails is
/// the whole route searched, so a rider who rejoins further on is picked up
/// again. Progress holds while the rider is away from the line and ignores the
/// small backward jitter of GPS. Pure Dart: no Flutter, no Firebase.
class RouteProgressTracker {
  RouteProgressTracker(this.guide, {OffRouteDetector? detector})
    : _detector = detector ?? OffRouteDetector();

  final RouteGuide guide;
  final OffRouteDetector _detector;

  double? _along;
  bool _arrived = false;

  /// Search window around the last position, along the route.
  static const double _lookBehindMeters = 80;
  static const double _lookAheadMeters = 600;

  /// A projection this close to the line is trusted as the rider's position.
  static const double _acceptMeters = 30;

  /// A projection beyond this from the line does not move progress.
  static const double _holdMeters = 45;

  /// Backward moves smaller than this are GPS jitter, not riding backwards.
  static const double _backwardJitterMeters = 15;

  /// The destination counts as reached within this distance.
  static const double _arriveMeters = 35;

  /// How far ahead to look for the point to rejoin the route.
  static const double _rejoinSearchMeters = 3000;

  /// The highlighted stretch ahead never runs longer than this.
  static const double _maxActiveMeters = 800;

  /// A rider's own average counts once they are moving at least this fast.
  static const double _minAverageMps = 2;

  /// Takes one fix and returns the rider's new standing on the route.
  /// [averageSpeedMps] (moving average so far) refines the time estimate.
  GuidanceSnapshot update(LocationFix fix, {double? averageSpeedMps}) {
    final g = guide.geometry;
    final q = fix.point;
    final last = _along;

    final RouteProjection chosen;
    if (last == null) {
      chosen = g.project(q);
    } else {
      final local = g.projectWithin(
        q,
        fromMeters: last - _lookBehindMeters,
        toMeters: last + _lookAheadMeters,
      );
      if (local.offsetMeters <= _acceptMeters) {
        chosen = local;
      } else {
        // Picked up somewhere else on the route (a shortcut, a loop)? Only
        // jump there when it is clearly closer than the expected stretch.
        final global = g.project(q);
        chosen = global.offsetMeters + 10 < local.offsetMeters &&
                global.offsetMeters <= _acceptMeters
            ? global
            : local;
      }
    }

    final offRoute = _detector.update(
      chosen.offsetMeters,
      accuracyMeters: q.accuracyMeters,
      timeMs: fix.timestamp.millisecondsSinceEpoch,
    );

    double along;
    if (last == null) {
      along = chosen.alongMeters;
    } else if (chosen.offsetMeters > _holdMeters) {
      along = last;
    } else if (chosen.alongMeters < last &&
        last - chosen.alongMeters < _backwardJitterMeters) {
      along = last;
    } else {
      along = chosen.alongMeters;
    }
    _along = along;

    final total = g.lengthMeters;
    if (!_arrived &&
        ((total - along <= _arriveMeters && chosen.offsetMeters <= 60) ||
            q.distanceMetersTo(g.end) <= _arriveMeters)) {
      _arrived = true;
    }
    if (_arrived) along = total;

    final nextIndex = guide.nextManeuverIndex(along, aheadMeters: 3);
    final next = nextIndex == null ? null : guide.maneuvers[nextIndex];
    final afterNext =
        nextIndex == null || nextIndex + 1 >= guide.maneuvers.length
        ? null
        : guide.maneuvers[nextIndex + 1];

    GeoPoint? rejoin;
    if (offRoute && !_arrived) {
      rejoin = g
          .projectWithin(
            q,
            fromMeters: along - 20,
            toMeters: along + _rejoinSearchMeters,
          )
          .point;
    }

    final double from = (along - 8).clamp(0.0, math.max(0.0, total - 1));
    final double to = (along + 18).clamp(math.min(from + 1, total), total);

    return GuidanceSnapshot(
      alongMeters: along,
      totalMeters: total,
      offsetMeters: chosen.offsetMeters,
      isOffRoute: offRoute && !_arrived,
      hasArrived: _arrived,
      riderPoint: q,
      snappedPoint: chosen.point,
      routeBearing: g.bearingBetween(from, to),
      activeEndMeters: math.min(
        next?.alongMeters ?? total,
        along + _maxActiveMeters,
      ),
      next: _arrived ? null : next,
      afterNext: _arrived ? null : afterNext,
      rejoinPoint: rejoin,
      remainingTime: _remainingTime(total - along, averageSpeedMps),
    );
  }

  Duration? _remainingTime(double meters, double? averageSpeedMps) {
    if (meters <= 0) return Duration.zero;
    final planned = guide.plannedSpeedMps;
    final own = averageSpeedMps ?? 0;
    final speed = own >= _minAverageMps
        ? (planned > 0 ? (own + planned) / 2 : own)
        : planned;
    if (speed <= 0) return null;
    return Duration(seconds: (meters / speed).round());
  }
}
