import '../../../core/errors/result.dart';
import 'destination.dart';
import 'geo_point.dart';

/// Contract for destination search and route computation.
///
/// The UI only talks to this interface. The current implementation calls
/// Google's Places and Routes REST APIs from the device; a server-backed
/// implementation can replace it later without any UI change.
abstract interface class RouteRepository {
  /// Autocomplete suggestions for [query], ranked toward [near] when given.
  ///
  /// Pass [newSession] for the first query of a search, so the keystrokes and
  /// the final selection are billed as one session.
  Future<Result<List<PlaceSuggestion>>> searchDestinations(
    String query, {
    GeoPoint? near,
    bool newSession = false,
  });

  /// Resolves a suggestion to a named location.
  Future<Result<Destination>> resolveDestination(String placeId);

  /// Computes a riding route from [origin] to [destination].
  Future<Result<RouteEstimate>> computeRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  });
}
