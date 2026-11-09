import 'geo_point.dart';

/// The group's planned route for a guided ride.
///
/// The host computes it once and saves it to the room; every rider downloads
/// the same copy and nobody recalculates it. Only the fields the ride needs
/// are stored.
class PlannedRoute {
  const PlannedRoute({
    required this.destinationName,
    required this.destination,
    required this.encodedPolyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final String destinationName;
  final GeoPoint destination;

  /// Route geometry in Google's encoded polyline format.
  final String encodedPolyline;

  /// Total route length.
  final int distanceMeters;

  /// Estimated riding time.
  final int durationSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlannedRoute &&
          other.destinationName == destinationName &&
          other.destination == destination &&
          other.encodedPolyline == encodedPolyline &&
          other.distanceMeters == distanceMeters &&
          other.durationSeconds == durationSeconds);

  @override
  int get hashCode => Object.hash(
        destinationName,
        destination,
        encodedPolyline,
        distanceMeters,
        durationSeconds,
      );
}
