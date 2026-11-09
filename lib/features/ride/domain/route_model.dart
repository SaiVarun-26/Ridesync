import 'geo_point.dart';

/// The group's planned route for a guided ride.
///
/// Generated on the server (Routes API, via the `getRoute` Cloud Function) and
/// shared through the room, so every rider holds exactly the same route.
class PlannedRoute {
  const PlannedRoute({
    required this.destinationName,
    required this.destinationAddress,
    required this.destination,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.encodedPolyline,
    required this.createdBy,
    this.createdAt,
  });

  final String destinationName;
  final String destinationAddress;
  final GeoPoint destination;

  /// Total route length.
  final int distanceMeters;

  /// Estimated riding time, traffic-aware at generation time.
  final int durationSeconds;

  /// The route geometry in Google's encoded polyline format.
  final String encodedPolyline;

  /// Uid of the host who generated it.
  final String createdBy;

  /// Server timestamp (epoch millis) of generation, when known.
  final int? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlannedRoute &&
          other.destinationName == destinationName &&
          other.destinationAddress == destinationAddress &&
          other.destination == destination &&
          other.distanceMeters == distanceMeters &&
          other.durationSeconds == durationSeconds &&
          other.encodedPolyline == encodedPolyline &&
          other.createdBy == createdBy &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(
        destinationName,
        destinationAddress,
        destination,
        distanceMeters,
        durationSeconds,
        encodedPolyline,
        createdBy,
        createdAt,
      );
}
