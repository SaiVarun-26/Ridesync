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
