import '../domain/geo_point.dart';
import '../domain/route_model.dart';

/// Realtime Database location and field names for a room's planned route.
///
/// The same names are written by the `getRoute` Cloud Function and checked by
/// the security rules, so they are defined once here.
abstract final class RoutePaths {
  static String route(String code) => 'rooms/$code/route';

  static const String destinationName = 'destinationName';
  static const String destinationAddress = 'destinationAddress';
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String distanceMeters = 'distanceMeters';
  static const String durationSeconds = 'durationSeconds';
  static const String polyline = 'polyline';
  static const String createdBy = 'createdBy';
  static const String createdAt = 'createdAt';

  const RoutePaths._();
}

/// Maps a stored or returned route map to a [PlannedRoute].
abstract final class RouteDto {
  /// Builds a [PlannedRoute], or returns `null` when [value] is absent or is
  /// missing a required field (an incomplete route is never shown).
  static PlannedRoute? fromValue(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);

    final name = map[RoutePaths.destinationName];
    final address = map[RoutePaths.destinationAddress];
    final latitude = map[RoutePaths.latitude];
    final longitude = map[RoutePaths.longitude];
    final distance = map[RoutePaths.distanceMeters];
    final duration = map[RoutePaths.durationSeconds];
    final polyline = map[RoutePaths.polyline];
    final createdBy = map[RoutePaths.createdBy];

    if (name is! String ||
        address is! String ||
        latitude is! num ||
        longitude is! num ||
        distance is! num ||
        duration is! num ||
        polyline is! String ||
        polyline.isEmpty ||
        createdBy is! String) {
      return null;
    }

    final createdAt = map[RoutePaths.createdAt];
    return PlannedRoute(
      destinationName: name,
      destinationAddress: address,
      destination: GeoPoint(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
      distanceMeters: distance.toInt(),
      durationSeconds: duration.toInt(),
      encodedPolyline: polyline,
      createdBy: createdBy,
      createdAt: createdAt is num ? createdAt.toInt() : null,
    );
  }
}
