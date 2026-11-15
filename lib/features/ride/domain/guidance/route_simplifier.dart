import 'dart:math' as math;
import 'dart:typed_data';

import '../geo_point.dart';
import '../polyline.dart';

/// Shrinks route lines without changing their shape noticeably.
abstract final class RouteSimplifier {
  /// Douglas–Peucker: drops points that lie within [toleranceMeters] of the
  /// line through their neighbours. Iterative, so very long routes cannot
  /// overflow the stack. The first and last points are always kept.
  static List<GeoPoint> simplify(
    List<GeoPoint> points, {
    required double toleranceMeters,
  }) {
    if (points.length < 3 || toleranceMeters <= 0) return points;
    // A flat frame around the route's middle latitude is plenty for deciding
    // which points matter.
    final midLat = points[points.length ~/ 2].latitude;
    const ky = 6371008.8 * math.pi / 180;
    final kx = ky * math.cos(midLat * math.pi / 180);
    final n = points.length;
    final x = Float64List(n);
    final y = Float64List(n);
    for (var i = 0; i < n; i++) {
      x[i] = points[i].longitude * kx;
      y[i] = points[i].latitude * ky;
    }
    final keep = Uint8List(n)
      ..[0] = 1
      ..[n - 1] = 1;
    final tolerance2 = toleranceMeters * toleranceMeters;
    final stack = <int>[0, n - 1];
    while (stack.isNotEmpty) {
      final last = stack.removeLast();
      final first = stack.removeLast();
      final dx = x[last] - x[first];
      final dy = y[last] - y[first];
      final len2 = dx * dx + dy * dy;
      var worst = -1.0;
      var worstIndex = -1;
      for (var i = first + 1; i < last; i++) {
        final px = x[i] - x[first];
        final py = y[i] - y[first];
        double d2;
        if (len2 <= 0) {
          d2 = px * px + py * py;
        } else {
          final t = ((px * dx + py * dy) / len2).clamp(0.0, 1.0);
          final cx = px - dx * t;
          final cy = py - dy * t;
          d2 = cx * cx + cy * cy;
        }
        if (d2 > worst) {
          worst = d2;
          worstIndex = i;
        }
      }
      if (worstIndex >= 0 && worst > tolerance2) {
        keep[worstIndex] = 1;
        stack
          ..add(first)
          ..add(worstIndex)
          ..add(worstIndex)
          ..add(last);
      }
    }
    return [
      for (var i = 0; i < n; i++)
        if (keep[i] == 1) points[i],
    ];
  }

  /// Encodes [points], simplifying only as much as needed to fit in
  /// [maxLength] characters. Returns `null` if even a coarse line cannot fit.
  static String? encodeWithin(List<GeoPoint> points, {required int maxLength}) {
    var encoded = encodePolyline(points);
    var tolerance = 2.0;
    while (encoded.length > maxLength) {
      if (tolerance > _maxToleranceMeters) return null;
      encoded = encodePolyline(
        simplify(points, toleranceMeters: tolerance),
      );
      tolerance *= 2;
    }
    return encoded;
  }

  /// Beyond this the route would visibly leave the road.
  static const double _maxToleranceMeters = 64;
}
