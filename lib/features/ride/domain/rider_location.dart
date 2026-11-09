import 'geo_point.dart';

/// A rider's last shared position during a live ride.
class RiderLocation {
  const RiderLocation({
    required this.uid,
    required this.point,
    this.headingDegrees,
    this.speedMps,
    this.updatedAt,
  });

  final String uid;
  final GeoPoint point;

  /// Direction of travel, 0–360° clockwise from north, when known.
  final double? headingDegrees;

  /// Ground speed in meters per second, when known.
  final double? speedMps;

  /// Server time (epoch millis) of the last update, when known.
  final int? updatedAt;
}

/// A change to the set of shared rider positions.
sealed class RiderLocationChange {
  const RiderLocationChange();
}

/// A rider shared a new position (or appeared for the first time).
final class RiderLocationUpdated extends RiderLocationChange {
  const RiderLocationUpdated(this.location);

  final RiderLocation location;
}

/// A rider's position was withdrawn (they left or disconnected).
final class RiderLocationRemoved extends RiderLocationChange {
  const RiderLocationRemoved(this.uid);

  final String uid;
}
