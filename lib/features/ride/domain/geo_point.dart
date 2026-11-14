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

  /// Initial compass bearing from here to [other], in degrees from north
  /// (0–360, clockwise).
  double bearingDegreesTo(GeoPoint other) {
    double rad(double degrees) => degrees * math.pi / 180;
    final lat1 = rad(latitude);
    final lat2 = rad(other.latitude);
    final dLng = rad(other.longitude - longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// The point [meters] away along compass [bearingDegrees].
  ///
  /// Uses a local flat-Earth step, which is exact to well under a centimetre
  /// over the few metres a marker is predicted ahead.
  GeoPoint offsetBy(double meters, double bearingDegrees) {
    final bearing = bearingDegrees * math.pi / 180;
    final dLat = meters * math.cos(bearing) / _earthRadiusMeters;
    final dLng =
        meters *
        math.sin(bearing) /
        (_earthRadiusMeters * math.cos(latitude * math.pi / 180));
    return GeoPoint(
      latitude: latitude + dLat * 180 / math.pi,
      longitude: longitude + dLng * 180 / math.pi,
    );
  }

  /// Whether [other] is the same place, ignoring accuracy.
  bool samePlaceAs(GeoPoint other) =>
      latitude == other.latitude && longitude == other.longitude;

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
