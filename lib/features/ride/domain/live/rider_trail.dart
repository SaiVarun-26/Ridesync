import '../geo_point.dart';

/// One recorded point of a rider's trail.
class TrailPoint {
  const TrailPoint({
    required this.point,
    required this.timeMs,
    this.startsSegment = false,
  });

  final GeoPoint point;

  /// When the rider was here (epoch millis, device clock).
  final int timeMs;

  /// Whether the trail restarts here, because the rider was away (backgrounded
  /// or without signal) and no path is known between this point and the one
  /// before it.
  final bool startsSegment;
}

/// A rider's whole ridden path, kept for the entire ride in bounded memory.
///
/// New points are recorded at full detail. When the trail grows past
/// [maxPoints], the older part is thinned to an even spacing along the path
/// while the most recent [recentPoints] stay untouched. Thinning only removes
/// detail from the old path, never the path itself, so the full shape of the
/// ride stays on the map however long it runs.
class RiderTrail {
  const RiderTrail([this.points = const []]);

  /// Oldest first.
  final List<TrailPoint> points;

  /// Minimum spacing between recorded points; closer GPS jitter is ignored.
  static const double minSpacingMeters = 4;

  /// Most points stored per rider before older detail is thinned.
  static const int maxPoints = 1500;

  /// Newest points that are never thinned.
  static const int recentPoints = 400;

  /// A silence longer than this means the rider was away, so the trail
  /// restarts instead of drawing a straight line across the gap.
  static const Duration gap = Duration(minutes: 2);

  /// This trail with [point] appended when it is far enough from the last one.
  /// Returns `this` when nothing changed.
  RiderTrail append(GeoPoint point, int nowMs) {
    final last = points.isEmpty ? null : points.last;
    if (last != null && last.point.distanceMetersTo(point) < minSpacingMeters) {
      return this;
    }
    final startsSegment =
        last != null && nowMs - last.timeMs > gap.inMilliseconds;
    final next = <TrailPoint>[
      ...points,
      TrailPoint(point: point, timeMs: nowMs, startsSegment: startsSegment),
    ];
    return RiderTrail(next.length > maxPoints ? _thinned(next) : next);
  }

  /// Share of the older budget the thinned path may fill, leaving room for
  /// the path to grow before the next thinning.
  static const double _olderFill = 0.6;

  /// [source] with its older part thinned to an even spacing along the path.
  ///
  /// The spacing is chosen so the whole older path fits in a fraction of the
  /// older budget, so every part of the ride keeps the same level of detail
  /// no matter how long the ride has run. Points that begin or end a segment
  /// and the last older point are always kept, so gaps stay gaps and the path
  /// joins the recent stretch.
  static List<TrailPoint> _thinned(List<TrailPoint> source) {
    final olderCount = source.length - recentPoints;

    var pathMeters = 0.0;
    for (var i = 1; i < olderCount; i++) {
      if (!source[i].startsSegment) {
        pathMeters += source[i - 1].point.distanceMetersTo(source[i].point);
      }
    }
    const budget = (maxPoints - recentPoints) * _olderFill;
    final spacing = pathMeters / budget > minSpacingMeters
        ? pathMeters / budget
        : minSpacingMeters;

    final result = <TrailPoint>[];
    var keptFrom = source.first.point;
    for (var i = 0; i < source.length; i++) {
      final p = source[i];
      if (i >= olderCount) {
        result.add(p);
        continue;
      }
      final boundary = i == 0 ||
          i == olderCount - 1 ||
          p.startsSegment ||
          source[i + 1].startsSegment;
      if (boundary || keptFrom.distanceMetersTo(p.point) >= spacing) {
        result.add(p);
        keptFrom = p.point;
      }
    }
    return result;
  }
}
