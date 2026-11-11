import 'dart:math' as math;

import '../../ride/domain/geo_point.dart';

/// Finds the places on a route where the rider turned around.
abstract final class UTurnDetector {
  /// How far either side of a point the direction of travel is measured.
  static const double legMeters = 80;

  /// A change of direction of at least this many degrees counts as turning
  /// around.
  static const double minTurnDegrees = 145;

  /// Turns closer together than this along the route count as one.
  static const double mergeMeters = 160;

  /// Indices into [points] of each U-turn, in route order.
  static List<int> find(List<GeoPoint> points) {
    final n = points.length;
    if (n < 3) return const [];

    final along = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      along[i] = along[i - 1] + points[i - 1].distanceMetersTo(points[i]);
    }

    // The sharpest turn score at each point, or 0 when it is not a turn.
    final scores = List<double>.filled(n, 0);
    var back = 0;
    var ahead = 0;
    for (var i = 1; i < n - 1; i++) {
      while (back < i - 1 && along[i] - along[back + 1] >= legMeters) {
        back++;
      }
      if (ahead < i) ahead = i;
      while (ahead < n - 1 && along[ahead] - along[i] < legMeters) {
        ahead++;
      }
      // Both legs must be long enough to say anything about direction.
      if (along[i] - along[back] < legMeters * 0.6 ||
          along[ahead] - along[i] < legMeters * 0.6) {
        continue;
      }
      final incoming = _bearing(points[back], points[i]);
      final outgoing = _bearing(points[i], points[ahead]);
      final turn = _angleBetween(incoming, outgoing);
      if (turn >= minTurnDegrees) scores[i] = turn;
    }

    // Keep only the sharpest point of each cluster of turns.
    final turns = <int>[];
    var i = 1;
    while (i < n - 1) {
      if (scores[i] == 0) {
        i++;
        continue;
      }
      var best = i;
      var j = i;
      while (j < n - 1 && along[j] - along[i] <= mergeMeters) {
        if (scores[j] > scores[best]) best = j;
        j++;
      }
      turns.add(best);
      i = j;
    }
    return turns;
  }

  /// Compass bearing from [a] to [b], in degrees.
  static double _bearing(GeoPoint a, GeoPoint b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// The smaller angle between two bearings, 0 to 180 degrees.
  static double _angleBetween(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }
}
