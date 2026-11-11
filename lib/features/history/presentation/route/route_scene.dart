import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../domain/ride_details.dart';
import '../../domain/speed_scale.dart';

/// One rider's route prepared for drawing.
class RouteRider {
  RouteRider({
    required this.uid,
    required this.color,
    required this.xs,
    required this.ys,
    required this.heat,
    required this.latLngs,
  });

  final String uid;

  /// The rider's own colour, used when speeds are unknown and for markers.
  final Color color;

  /// Positions in the scene's local pixel space (see [RouteScene]).
  final Float64List xs;
  final Float64List ys;

  /// How fast the rider was at each point, 0 (slowest) to 1 (fastest); `null`
  /// when the ride's speeds were not recorded.
  final Float64List? heat;

  final List<LatLng> latLngs;

  int get length => xs.length;
}

/// All riders' routes of a ride, laid out once in a local pixel space so each
/// frame only needs a small transform to put them on the screen.
///
/// Positions are stored as Web Mercator pixels at zoom [referenceZoom], taken
/// relative to the middle of the ride. Because that space is a straight
/// scale-and-rotate away from the screen at any zoom and map rotation, one
/// transform per frame places every point exactly, with no per-point map
/// projection.
class RouteScene {
  RouteScene._(this.riders, this._origin, this._originPx);

  static const double referenceZoom = 16;
  static const Epsg3857 _crs = Epsg3857();

  final List<RouteRider> riders;
  final LatLng _origin;
  final Offset _originPx;

  RouteRider? rider(String uid) {
    for (final r in riders) {
      if (r.uid == uid) return r;
    }
    return null;
  }

  /// Prepares [routes] for drawing. [colors] gives each rider's colour and
  /// [scale] turns their speeds into heat.
  factory RouteScene.build({
    required Map<String, RiderRoute> routes,
    required Map<String, Color> colors,
    required SpeedScale scale,
  }) {
    var south = double.infinity;
    var north = -double.infinity;
    var west = double.infinity;
    var east = -double.infinity;
    for (final route in routes.values) {
      for (final p in route.points) {
        south = math.min(south, p.latitude);
        north = math.max(north, p.latitude);
        west = math.min(west, p.longitude);
        east = math.max(east, p.longitude);
      }
    }
    final origin = routes.isEmpty
        ? const LatLng(0, 0)
        : LatLng((south + north) / 2, (west + east) / 2);
    final originPx = _crs.latLngToOffset(origin, referenceZoom);

    final riders = <RouteRider>[];
    routes.forEach((uid, route) {
      final n = route.points.length;
      final xs = Float64List(n);
      final ys = Float64List(n);
      final latLngs = <LatLng>[];
      for (var i = 0; i < n; i++) {
        final p = route.points[i];
        final ll = LatLng(p.latitude, p.longitude);
        final px = _crs.latLngToOffset(ll, referenceZoom) - originPx;
        xs[i] = px.dx;
        ys[i] = px.dy;
        latLngs.add(ll);
      }
      Float64List? heat;
      if (route.hasSpeeds) {
        final smooth = route.smoothedSpeedsMps;
        heat = Float64List(n);
        for (var i = 0; i < n; i++) {
          heat[i] = scale.normalize(smooth[i]);
        }
      }
      riders.add(
        RouteRider(
          uid: uid,
          color: colors[uid] ?? const Color(0xFFFFFFFF),
          xs: xs,
          ys: ys,
          heat: heat,
          latLngs: latLngs,
        ),
      );
    });
    return RouteScene._(riders, origin, originPx);
  }

  /// The transform that places this scene on the screen for [camera].
  RouteTransform transformFor(MapCamera camera) {
    const probe = 256.0;
    final s0 = camera.latLngToScreenOffset(_origin);
    final sx = camera.latLngToScreenOffset(
      _crs.offsetToLatLng(_originPx + const Offset(probe, 0), referenceZoom),
    );
    final sy = camera.latLngToScreenOffset(
      _crs.offsetToLatLng(_originPx + const Offset(0, probe), referenceZoom),
    );
    return RouteTransform(
      originX: s0.dx,
      originY: s0.dy,
      ax: (sx.dx - s0.dx) / probe,
      ay: (sx.dy - s0.dy) / probe,
      bx: (sy.dx - s0.dx) / probe,
      by: (sy.dy - s0.dy) / probe,
    );
  }

  /// The rider nearest to [tap] on the screen, if one is within [reach]
  /// pixels of their route.
  String? riderNear(Offset tap, MapCamera camera, {double reach = 26}) {
    final transform = transformFor(camera);
    String? best;
    var bestDistance = reach;
    for (final rider in riders) {
      final screen = ProjectedRoute.project(rider, transform, laneOffset: 0);
      final d = screen.distanceTo(tap);
      if (d < bestDistance) {
        bestDistance = d;
        best = rider.uid;
      }
    }
    return best;
  }
}

/// Maps scene positions to screen positions: a uniform scale and a rotation
/// plus a shift.
class RouteTransform {
  const RouteTransform({
    required this.originX,
    required this.originY,
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
  });

  final double originX;
  final double originY;
  final double ax;
  final double ay;
  final double bx;
  final double by;

  double mapX(double x, double y) => originX + ax * x + bx * y;
  double mapY(double x, double y) => originY + ay * x + by * y;
}

/// One rider's route on the screen, thinned to what a screen can show and
/// shifted slightly to the right of the direction of travel.
///
/// The shift keeps an out-and-back ride readable: where the way out and the
/// way back share a road, they run side by side instead of on top of each
/// other.
class ProjectedRoute {
  ProjectedRoute._(this.rider, this.xs, this.ys, this.source, this.along);

  final RouteRider rider;

  /// Screen positions of the kept points.
  final Float64List xs;
  final Float64List ys;

  /// For each kept point, its index in the rider's full route.
  final Int32List source;

  /// Distance travelled along the screen path to each kept point.
  final Float64List along;

  int get length => xs.length;

  double get totalLength => length == 0 ? 0 : along[length - 1];

  /// Points closer together than this on screen are merged.
  static const double _minStep = 1.6;

  factory ProjectedRoute.project(
    RouteRider rider,
    RouteTransform t, {
    required double laneOffset,
  }) {
    final n = rider.length;
    // Unboxed buffers sized once, so a frame allocates no per-point objects.
    final px = Float64List(n);
    final py = Float64List(n);
    final idx = Int32List(n);
    var count = 0;
    for (var i = 0; i < n; i++) {
      final x = t.mapX(rider.xs[i], rider.ys[i]);
      final y = t.mapY(rider.xs[i], rider.ys[i]);
      if (count > 0 && i != n - 1) {
        final dx = x - px[count - 1];
        final dy = y - py[count - 1];
        if (dx * dx + dy * dy < _minStep * _minStep) continue;
      }
      px[count] = x;
      py[count] = y;
      idx[count] = i;
      count++;
    }

    final xs = Float64List(count);
    final ys = Float64List(count);
    for (var i = 0; i < count; i++) {
      var ox = 0.0;
      var oy = 0.0;
      if (laneOffset != 0 && count > 1) {
        // Direction of travel here, from the neighbours on either side.
        final a = i == 0 ? 0 : i - 1;
        final b = i == count - 1 ? count - 1 : i + 1;
        final dx = px[b] - px[a];
        final dy = py[b] - py[a];
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 1e-6) {
          // Right-hand side of travel on a screen whose y axis points down.
          ox = -dy / len * laneOffset;
          oy = dx / len * laneOffset;
        }
      }
      xs[i] = px[i] + ox;
      ys[i] = py[i] + oy;
    }

    final along = Float64List(count);
    for (var i = 1; i < count; i++) {
      final dx = xs[i] - xs[i - 1];
      final dy = ys[i] - ys[i - 1];
      along[i] = along[i - 1] + math.sqrt(dx * dx + dy * dy);
    }
    return ProjectedRoute._(
      rider,
      xs,
      ys,
      Int32List.sublistView(idx, 0, count),
      along,
    );
  }

  /// Shortest distance from [p] to this route, in pixels.
  double distanceTo(Offset p) {
    var best = double.infinity;
    for (var i = 1; i < length; i++) {
      final d = _segmentDistance(
        p.dx,
        p.dy,
        xs[i - 1],
        ys[i - 1],
        xs[i],
        ys[i],
      );
      if (d < best) best = d;
    }
    return best;
  }

  static double _segmentDistance(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    final ex = px - cx;
    final ey = py - cy;
    return math.sqrt(ex * ex + ey * ey);
  }
}
