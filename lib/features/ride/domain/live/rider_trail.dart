import '../geo_point.dart';

/// One recorded point of a rider's trail.
class TrailPoint {
  const TrailPoint({required this.point, required this.timeMs});

  final GeoPoint point;

  /// When the rider was here (epoch millis, device clock).
  final int timeMs;
}

/// A rider's recent path, bounded in both length and age so memory stays
/// flat for the whole ride.
class RiderTrail {
  const RiderTrail([this.points = const []]);

  /// Oldest first.
  final List<TrailPoint> points;

  /// Minimum spacing between recorded points; closer GPS jitter is ignored.
  static const double minSpacingMeters = 4;

  /// Hard cap on stored points per rider.
  static const int maxPoints = 240;

  /// Points older than this are dropped; the trail fades out over this span.
  static const Duration window = Duration(minutes: 8);

  /// This trail with [point] appended (when far enough from the last one)
  /// and expired points removed. Returns `this` when nothing changed.
  RiderTrail append(GeoPoint point, int nowMs) {
    final last = points.isEmpty ? null : points.last;
    final moved =
        last == null || last.point.distanceMetersTo(point) >= minSpacingMeters;
    final cutoff = nowMs - window.inMilliseconds;
    final expired = points.isNotEmpty && points.first.timeMs < cutoff;
    if (!moved && !expired) return this;

    final next = <TrailPoint>[
      for (final p in points)
        if (p.timeMs >= cutoff) p,
      if (moved) TrailPoint(point: point, timeMs: nowMs),
    ];
    final overflow = next.length - maxPoints;
    return RiderTrail(overflow > 0 ? next.sublist(overflow) : next);
  }

  /// This trail with expired points removed.
  RiderTrail prune(int nowMs) {
    final cutoff = nowMs - window.inMilliseconds;
    if (points.isEmpty || points.first.timeMs >= cutoff) return this;
    return RiderTrail([
      for (final p in points)
        if (p.timeMs >= cutoff) p,
    ]);
  }
}
