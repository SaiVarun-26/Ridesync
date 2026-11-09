import '../../../core/errors/result.dart';
import 'geo_point.dart';

/// One autocomplete suggestion while searching for a destination.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;

  /// The place's name, e.g. "Marina Beach".
  final String primaryText;

  /// Where it is, e.g. "Chennai, Tamil Nadu, India".
  final String secondaryText;
}

/// A chosen place, resolved to coordinates.
class PlaceDetails {
  const PlaceDetails({
    required this.name,
    required this.address,
    required this.location,
  });

  final String name;
  final String address;
  final GeoPoint location;
}

/// Contract for destination search (Google Places API (New) in production).
abstract interface class PlacesRepository {
  /// Autocomplete suggestions for [query], ranked toward [near] when given.
  ///
  /// Pass [newSession] for the first query of a search, so the keystrokes and
  /// the final selection are billed as one session.
  Future<Result<List<PlaceSuggestion>>> search(
    String query, {
    GeoPoint? near,
    bool newSession = false,
  });

  /// Resolves a suggestion to its name, address, and coordinates.
  Future<Result<PlaceDetails>> details(String placeId);
}
