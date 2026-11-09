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

/// A chosen destination, resolved to coordinates.
class Destination {
  const Destination({required this.name, required this.location});

  final String name;
  final GeoPoint location;
}

/// A computed route before it is shared with the group.
class RouteEstimate {
  const RouteEstimate({
    required this.encodedPolyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final String encodedPolyline;
  final int distanceMeters;
  final int durationSeconds;
}
