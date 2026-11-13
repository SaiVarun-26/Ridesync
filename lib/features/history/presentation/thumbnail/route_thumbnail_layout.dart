import 'dart:math' as math;
import 'dart:ui';

import '../../../ride/domain/geo_point.dart';
import '../../domain/speed_scale.dart';

/// A ride's route laid out for a thumbnail: where each point falls in a unit
/// square, and how fast the rider was there.
///
/// Pure geometry, with nothing to do with painting. The route is flattened
/// (a degree of longitude is no wider than a degree of latitude at that
/// place on Earth), scaled to fit and centred, so the same ride always has
/// the same shape and the shape is recognisable at any size.
class RouteThumbnailLayout {
  RouteThumbnailLayout._(this.points, this.heat);

  /// Each point of the route in the unit square, `(0, 0)` to `(1, 1)`.
  final List<Offset> points;

  /// How fast the rider was at each point, 0 (slowest) to 1 (fastest). Empty
  /// when speeds were not recorded.
  final List<double> heat;

  bool get hasHeat => heat.length == points.length && heat.isNotEmpty;

  /// Fewer points than this make no route.
  static const int minPoints = 2;

  /// Remembers layouts by the list of points they were made from, so a card
  /// that rebuilds (scrolling, pressing) never lays its route out again.
  static final Expando<RouteThumbnailLayout> _cache =
      Expando<RouteThumbnailLayout>('RouteThumbnailLayout');

  /// The layout for [points] and [speedsMps], or `null` when there is no
  /// route to draw.
  static RouteThumbnailLayout? of(
    List<GeoPoint> points,
    List<double> speedsMps,
  ) {
    if (points.length < minPoints) return null;
    return _cache[points] ??= _build(points, speedsMps);
  }

  static RouteThumbnailLayout _build(
    List<GeoPoint> points,
    List<double> speedsMps,
  ) {
    final meanLat =
        points.fold<double>(0, (sum, p) => sum + p.latitude) / points.length;
    final xScale = math.cos(meanLat * math.pi / 180);

    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final p in points) {
      final x = p.longitude * xScale;
      final y = -p.latitude;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final width = math.max(maxX - minX, 1e-9);
    final height = math.max(maxY - minY, 1e-9);
    final side = math.max(width, height);
    // Centre the shorter side so the route sits in the middle of the square.
    final offsetX = (side - width) / 2;
    final offsetY = (side - height) / 2;

    final unit = <Offset>[
      for (final p in points)
        Offset(
          (p.longitude * xScale - minX + offsetX) / side,
          (-p.latitude - minY + offsetY) / side,
        ),
    ];

    var heat = const <double>[];
    if (speedsMps.length == points.length) {
      final smooth = SpeedScale.smooth(speedsMps, radius: 1);
      final scale = SpeedScale.fromSeries([smooth]);
      heat = [for (final s in smooth) scale.normalize(s)];
    }
    return RouteThumbnailLayout._(unit, heat);
  }
}
