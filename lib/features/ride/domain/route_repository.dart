import '../../../core/errors/result.dart';
import 'destination.dart';
import 'geo_point.dart';

/// Contract for destination search and route computation.
///
/// The UI only talks to this interface. The current implementation uses free,
/// open services built on OpenStreetMap data (see `OsmRouteRepository`); a
/// server-backed or commercial implementation can replace it later without
/// any UI change.
abstract interface class RouteRepository {
  /// Suggestions for [query], ranked toward [near] when given.
  ///
  /// [newSession] marks the first query of a search, for providers that bill
  /// a whole search as one session.
  Future<Result<List<PlaceSuggestion>>> searchDestinations(
    String query, {
    GeoPoint? near,
    bool newSession = false,
  });

  /// Resolves a suggestion to a named location.
  Future<Result<Destination>> resolveDestination(String placeId);

  /// Names the place at [at] (a point picked on the map).
  Future<Result<Destination>> describeLocation(GeoPoint at);

  /// Computes a riding route from [origin] to [destination].
  Future<Result<RouteEstimate>> computeRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  });
}
