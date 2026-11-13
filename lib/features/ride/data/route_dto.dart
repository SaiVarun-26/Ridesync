import '../domain/geo_point.dart';
import '../domain/route_model.dart';

/// Realtime Database location and field names for a room's planned route.
///
/// The security rules check exactly these fields, so they are defined once.
abstract final class RoutePaths {
  static String route(String code) => 'rooms/$code/route';

  static const String destinationName = 'destinationName';
  static const String destinationLatitude = 'destinationLatitude';
  static const String destinationLongitude = 'destinationLongitude';
  static const String encodedPolyline = 'encodedPolyline';
  static const String distanceMeters = 'distanceMeters';
  static const String durationSeconds = 'durationSeconds';

  const RoutePaths._();
}

/// Maps between the stored route and [PlannedRoute].
abstract final class RouteDto {
  /// Builds a [PlannedRoute], or `null` when [value] is absent or incomplete
  /// (an incomplete route is never shown).
  static PlannedRoute? fromValue(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);

    final name = map[RoutePaths.destinationName];
    final latitude = map[RoutePaths.destinationLatitude];
    final longitude = map[RoutePaths.destinationLongitude];
    final polyline = map[RoutePaths.encodedPolyline];
    final distance = map[RoutePaths.distanceMeters];
    final duration = map[RoutePaths.durationSeconds];

    if (name is! String ||
        latitude is! num ||
        longitude is! num ||
        polyline is! String ||
        polyline.isEmpty ||
        distance is! num ||
        duration is! num) {
      return null;
    }
    return PlannedRoute(
      destinationName: name,
      destination: GeoPoint(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
      encodedPolyline: polyline,
      distanceMeters: distance.toInt(),
      durationSeconds: duration.toInt(),
    );
  }

  /// The six stored fields, and nothing else.
  static Map<String, Object?> toValue(PlannedRoute route) => <String, Object?>{
    RoutePaths.destinationName: route.destinationName,
    RoutePaths.destinationLatitude: route.destination.latitude,
    RoutePaths.destinationLongitude: route.destination.longitude,
    RoutePaths.encodedPolyline: route.encodedPolyline,
    RoutePaths.distanceMeters: route.distanceMeters,
    RoutePaths.durationSeconds: route.durationSeconds,
  };
}
