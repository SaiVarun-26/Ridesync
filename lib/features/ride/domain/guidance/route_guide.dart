import '../polyline.dart';
import '../route_model.dart';
import 'route_geometry.dart';
import 'route_maneuvers.dart';

/// A planned route made ready for guidance: its measured line and its turns.
///
/// Built once per route (in a background isolate, see the guidance
/// providers) and then only read, so every per-fix calculation stays cheap.
class RouteGuide {
  RouteGuide._(this.route, this.geometry, this.maneuvers);

  /// Decodes and analyses [route]. Pure and synchronous: call it off the UI
  /// thread for long routes.
  factory RouteGuide.build(PlannedRoute route) {
    final geometry = RouteGeometry(decodePolyline(route.encodedPolyline));
    return RouteGuide._(route, geometry, ManeuverDetector.detect(geometry));
  }

  final PlannedRoute route;
  final RouteGeometry geometry;

  /// Turns in order, always ending with the arrival.
  final List<RouteManeuver> maneuvers;

  bool get isUsable => geometry.isUsable;

  double get lengthMeters => geometry.lengthMeters;

  /// The planned average speed, from the router's own estimate.
  double get plannedSpeedMps {
    final seconds = route.durationSeconds;
    if (seconds <= 0) return 0;
    return route.distanceMeters / seconds;
  }

  /// Index of the first manoeuvre beyond [alongMeters] (plus [aheadMeters]),
  /// or `null` when none is left.
  int? nextManeuverIndex(double alongMeters, {double aheadMeters = 0}) {
    final at = alongMeters + aheadMeters;
    var lo = 0;
    var hi = maneuvers.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (maneuvers[mid].alongMeters <= at) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo < maneuvers.length ? lo : null;
  }
}
