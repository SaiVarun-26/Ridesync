import 'dart:math' as math;
import 'dart:typed_data';

import '../geo_point.dart';

/// Where a point lands on a route.
class RouteProjection {
  const RouteProjection({
    required this.segment,
    required this.alongMeters,
    required this.offsetMeters,
    required this.point,
  });

  /// Index of the first vertex of the segment the point projects onto.
  final int segment;

  /// Distance from the route's start to the projected point, along the route.
  final double alongMeters;

  /// Straight-line distance from the point to the route (cross-track).
  final double offsetMeters;

  /// The nearest point on the route.
  final GeoPoint point;
}

/// A route line with everything needed to measure along it, precomputed once.
///
/// Distances along the route are cumulative haversine lengths. Projections are
/// done in a small flat frame around the query point, which is accurate to
/// centimetres over the few hundred metres a projection spans and costs only a
/// handful of multiplications per segment. Pure Dart and immutable, so it can
/// be built in a background isolate and shared freely.
class RouteGeometry {
  RouteGeometry._(this.points, this._lat, this._lng, this._along);

  /// Builds the geometry for [raw], dropping repeated points.
  factory RouteGeometry(List<GeoPoint> raw) {
    final points = <GeoPoint>[];
    for (final p in raw) {
      if (points.isEmpty || points.last.distanceMetersTo(p) > _duplicateMeters) {
        points.add(GeoPoint(latitude: p.latitude, longitude: p.longitude));
      }
    }
    final n = points.length;
    final lat = Float64List(n);
    final lng = Float64List(n);
    final along = Float64List(n);
    for (var i = 0; i < n; i++) {
      lat[i] = points[i].latitude;
      lng[i] = points[i].longitude;
      if (i > 0) {
        along[i] = along[i - 1] + points[i - 1].distanceMetersTo(points[i]);
      }
    }
    return RouteGeometry._(List.unmodifiable(points), lat, lng, along);
  }

  /// Points closer than this to the previous one add nothing.
  static const double _duplicateMeters = 0.5;

  /// Metres per degree of latitude on the mean Earth sphere.
  static const double _metersPerDegree = 6371008.8 * math.pi / 180;

  final List<GeoPoint> points;
  final Float64List _lat;
  final Float64List _lng;
  final Float64List _along;

  /// Whether there is a line to follow at all.
  bool get isUsable => points.length >= 2 && lengthMeters > 0;

  /// Number of vertices.
  int get length => points.length;

  /// Number of segments.
  int get segmentCount => math.max(0, points.length - 1);

  double get lengthMeters => _along.isEmpty ? 0 : _along[_along.length - 1];

  GeoPoint get start => points.first;
  GeoPoint get end => points.last;

  /// Distance along the route at vertex [index].
  double alongAt(int index) => _along[index];

  /// Index of the segment containing [alongMeters] (clamped to the route).
  int segmentAt(double alongMeters) {
    if (segmentCount == 0) return 0;
    if (alongMeters <= 0) return 0;
    if (alongMeters >= lengthMeters) return segmentCount - 1;
    var lo = 0;
    var hi = _along.length - 1;
    // Largest i with _along[i] <= alongMeters.
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_along[mid] <= alongMeters) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return math.min(lo, segmentCount - 1);
  }

  /// The point [alongMeters] from the start, clamped to the route.
  GeoPoint pointAt(double alongMeters) {
    if (points.length == 1) return points.first;
    final i = segmentAt(alongMeters);
    final from = _along[i];
    final span = _along[i + 1] - from;
    final t = span <= 0 ? 0.0 : ((alongMeters - from) / span).clamp(0.0, 1.0);
    return GeoPoint(
      latitude: _lat[i] + (_lat[i + 1] - _lat[i]) * t,
      longitude: _lng[i] + (_lng[i + 1] - _lng[i]) * t,
    );
  }

  /// Compass direction of the route between [fromMeters] and [toMeters].
  double bearingBetween(double fromMeters, double toMeters) =>
      pointAt(fromMeters).bearingDegreesTo(pointAt(toMeters));

  /// Projects [query] onto segments `[fromSegment, toSegment)` and returns the
  /// nearest result. Searches the whole route by default.
  RouteProjection project(
    GeoPoint query, {
    int fromSegment = 0,
    int? toSegment,
  }) {
    final int first = fromSegment.clamp(0, math.max(0, segmentCount - 1));
    final int last = (toSegment ?? segmentCount).clamp(
      math.min(first + 1, segmentCount),
      segmentCount,
    );
    final qLat = query.latitude;
    final qLng = query.longitude;
    final kx = _metersPerDegree * math.cos(qLat * math.pi / 180);
    const ky = _metersPerDegree;

    var bestDistance2 = double.infinity;
    var bestSegment = first;
    var bestT = 0.0;
    for (var i = first; i < last; i++) {
      final ax = (_lng[i] - qLng) * kx;
      final ay = (_lat[i] - qLat) * ky;
      final dx = (_lng[i + 1] - _lng[i]) * kx;
      final dy = (_lat[i + 1] - _lat[i]) * ky;
      final len2 = dx * dx + dy * dy;
      var t = len2 <= 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
      if (t < 0) {
        t = 0;
      } else if (t > 1) {
        t = 1;
      }
      final cx = ax + dx * t;
      final cy = ay + dy * t;
      final d2 = cx * cx + cy * cy;
      if (d2 < bestDistance2) {
        bestDistance2 = d2;
        bestSegment = i;
        bestT = t;
      }
    }
    if (segmentCount == 0) {
      return RouteProjection(
        segment: 0,
        alongMeters: 0,
        offsetMeters: points.isEmpty ? 0 : points.first.distanceMetersTo(query),
        point: points.isEmpty ? query : points.first,
      );
    }
    final i = bestSegment;
    final along = _along[i] + (_along[i + 1] - _along[i]) * bestT;
    return RouteProjection(
      segment: i,
      alongMeters: along,
      offsetMeters: math.sqrt(bestDistance2),
      point: GeoPoint(
        latitude: _lat[i] + (_lat[i + 1] - _lat[i]) * bestT,
        longitude: _lng[i] + (_lng[i + 1] - _lng[i]) * bestT,
      ),
    );
  }

  /// Like [project], but the line continues straight past both ends.
  ///
  /// A point beyond the end gets an [RouteProjection.alongMeters] greater than
  /// [lengthMeters] (negative before the start), and its offset is measured to
  /// the extended line. This is what lets a ridden path, which ends where the
  /// rider is, say that someone further down the road is ahead of it.
  RouteProjection projectExtended(GeoPoint query) {
    final base = project(query);
    if (!isUsable) return base;
    final total = lengthMeters;
    final atEnd = base.alongMeters >= total - 0.01;
    final atStart = base.alongMeters <= 0.01;
    if (!atEnd && !atStart) return base;

    // Direction of the line at the end being extended, measured over a
    // short stretch so one noisy point cannot swing it.
    final anchor = atEnd ? end : start;
    final bearing = atEnd
        ? bearingBetween(math.max(0, total - _extensionSpanMeters), total)
        : bearingBetween(math.min(total, _extensionSpanMeters), 0);
    final kx = _metersPerDegree * math.cos(anchor.latitude * math.pi / 180);
    final dx = (query.longitude - anchor.longitude) * kx;
    final dy = (query.latitude - anchor.latitude) * _metersPerDegree;
    final b = bearing * math.pi / 180;
    // Distance along the outward direction, and sideways from the line.
    final outward = dx * math.sin(b) + dy * math.cos(b);
    if (outward <= 0) return base;
    final side = (dx * math.cos(b) - dy * math.sin(b)).abs();
    return RouteProjection(
      segment: base.segment,
      alongMeters: atEnd ? total + outward : -outward,
      offsetMeters: side,
      point: anchor,
    );
  }

  /// How much of the line's end sets the direction of its extension.
  static const double _extensionSpanMeters = 25;

  /// Projects [query] onto the stretch between [fromMeters] and [toMeters].
  RouteProjection projectWithin(
    GeoPoint query, {
    required double fromMeters,
    required double toMeters,
  }) => project(
    query,
    fromSegment: segmentAt(fromMeters),
    toSegment: segmentAt(toMeters) + 1,
  );
}
