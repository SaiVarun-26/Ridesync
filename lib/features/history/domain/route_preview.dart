import '../../ride/domain/geo_point.dart';

/// A small version of a ride's route, for the miniature on a history card.
abstract final class RoutePreview {
  /// Most points a preview keeps. Small enough to store with the history entry
  /// (about 500 characters encoded) and plenty to show a route's shape.
  static const int maxPoints = 48;

  /// [points] reduced to at most [maxPoints], evenly spaced along the list and
  /// always keeping the first and last point.
  static List<GeoPoint> thin(List<GeoPoint> points) {
    if (points.length <= maxPoints) return List.unmodifiable(points);
    final result = <GeoPoint>[];
    final step = (points.length - 1) / (maxPoints - 1);
    for (var i = 0; i < maxPoints; i++) {
      result.add(points[(i * step).round()]);
    }
    return List.unmodifiable(result);
  }
}
