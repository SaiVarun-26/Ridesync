import 'dart:math' as math;

/// A location on Earth, independent of any map or location SDK.
///
/// Domain code passes these around so presentation and data layers can swap
/// map or GPS providers without touching business logic.
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;

  /// Estimated horizontal accuracy of a GPS fix, when known.
  final double? accuracyMeters;

  /// Mean Earth radius used for distance calculations.
  static const double _earthRadiusMeters = 6371008.8;

  /// Great-circle (haversine) distance to [other], in meters.
  double distanceMetersTo(GeoPoint other) {
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusMeters * math.asin(math.sqrt(a));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeoPoint &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.accuracyMeters == accuracyMeters);

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters);
}
