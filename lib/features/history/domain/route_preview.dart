import '../../ride/domain/geo_point.dart';

/// A small version of a ride's route, for the miniature on a history card.
abstract final class RoutePreview {
  /// Most points a preview keeps. Small enough to store with the history entry
  /// (about 500 characters encoded) and plenty to show a route's shape.
  static const int maxPoints = 48;

  /// Which of [length] points a preview keeps: at most [maxPoints], evenly
  /// spaced, always including the first and the last.
  static List<int> indices(int length) {
    if (length <= maxPoints) return [for (var i = 0; i < length; i++) i];
    final step = (length - 1) / (maxPoints - 1);
    return [for (var i = 0; i < maxPoints; i++) (i * step).round()];
  }

  /// [points] reduced to at most [maxPoints], evenly spaced along the list
  /// and always keeping the first and last point.
  static List<GeoPoint> thin(List<GeoPoint> points) =>
      List.unmodifiable([for (final i in indices(points.length)) points[i]]);

  /// [values] reduced the same way as [thin] reduces points, so the two stay
  /// in step.
  static List<double> thinValues(List<double> values) =>
      List.unmodifiable([for (final i in indices(values.length)) values[i]]);
}
