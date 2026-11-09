import '../../../core/errors/result.dart';
import 'geo_point.dart';
import 'places_repository.dart';
import 'route_model.dart';

/// Contract for the group's planned route.
///
/// Routes are generated on the server so the routing API key never ships in
/// the app; clients only request generation and observe the result.
abstract interface class RouteRepository {
  /// The planned route for room [code], live. Emits `null` until one exists.
  Stream<PlannedRoute?> watchRoute({required String code});

  /// Asks the server to compute the route from [origin] to [destination] for
  /// room [code] and share it with every rider. Host only.
  Future<Result<PlannedRoute>> generateRoute({
    required String code,
    required GeoPoint origin,
    required PlaceDetails destination,
  });
}
