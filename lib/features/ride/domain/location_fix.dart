import 'geo_point.dart';

/// One reading from the device's location service while riding.
class LocationFix {
  const LocationFix({
    required this.point,
    required this.timestamp,
    this.headingDegrees,
    this.speedMps,
  });

  /// Where the device is; carries the fix's accuracy when known.
  final GeoPoint point;

  /// When the fix was taken.
  final DateTime timestamp;

  /// Direction of travel, 0–360° clockwise from north, when known.
  final double? headingDegrees;

  /// Ground speed in meters per second, when known.
  final double? speedMps;
}
