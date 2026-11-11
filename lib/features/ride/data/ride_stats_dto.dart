import '../domain/geo_point.dart';
import '../domain/stats/ride_stats.dart';

/// Realtime Database layout for a rider's ride record:
///
/// - `rideStats/{roomCode}/{uid}`: the numbers (small, saved every few
///   seconds, readable by the room).
/// - `rideRoutes/{roomCode}/{uid}`: the whole-ride route as an encoded
///   polyline (larger, saved less often, kept apart so listening to the
///   numbers never downloads it).
abstract final class RideStatsPaths {
  static String stats(String code) => 'rideStats/$code';
  static String routes(String code) => 'rideRoutes/$code';

  // rideStats fields
  static const String distanceMeters = 'distanceMeters';
  static const String movingTimeMs = 'movingTimeMs';
  static const String maxSpeedMps = 'maxSpeedMps';
  static const String topSpeedAt = 'topSpeedAt';
  static const String sampleCount = 'sampleCount';
  static const String startedAt = 'startedAt';
  static const String updatedAt = 'updatedAt';
  static const String lastLatitude = 'lastLatitude';
  static const String lastLongitude = 'lastLongitude';
  static const String lastSampleAt = 'lastSampleAt';
  static const String finished = 'finished';
  static const String endedAt = 'endedAt';

  // rideRoutes fields
  static const String polyline = 'polyline';
  static const String speeds = 'speeds';

  const RideStatsPaths._();
}

/// Maps between [RideStats] and its stored form.
abstract final class RideStatsDto {
  /// Builds [RideStats] from a stored map, or `null` if it is absent or
  /// incomplete.
  static RideStats? fromValue(Object? value) {
    if (value is! Map) return null;
    final startedAt = value[RideStatsPaths.startedAt];
    if (startedAt is! num) return null;

    final lat = value[RideStatsPaths.lastLatitude];
    final lng = value[RideStatsPaths.lastLongitude];
    final topSpeedAt = value[RideStatsPaths.topSpeedAt];
    final lastSampleAt = value[RideStatsPaths.lastSampleAt];
    final endedAt = value[RideStatsPaths.endedAt];
    return RideStats(
      startedAtMs: startedAt.toInt(),
      distanceMeters: _number(value[RideStatsPaths.distanceMeters]),
      movingTimeMs: _number(value[RideStatsPaths.movingTimeMs]).toInt(),
      maxSpeedMps: _number(value[RideStatsPaths.maxSpeedMps]),
      topSpeedAtMs: topSpeedAt is num ? topSpeedAt.toInt() : null,
      sampleCount: _number(value[RideStatsPaths.sampleCount]).toInt(),
      lastPoint: lat is num && lng is num
          ? GeoPoint(latitude: lat.toDouble(), longitude: lng.toDouble())
          : null,
      lastSampleAtMs: lastSampleAt is num ? lastSampleAt.toInt() : null,
      // Finished only counts when both the flag and its timestamp are there.
      endedAtMs: value[RideStatsPaths.finished] == true && endedAt is num
          ? endedAt.toInt()
          : null,
    );
  }

  /// The stored form of [stats]. [updatedAt] is the database's server
  /// timestamp placeholder.
  static Map<String, Object?> toValue(RideStats stats, Object updatedAt) {
    final point = stats.lastPoint;
    final topSpeedAt = stats.topSpeedAtMs;
    final lastSampleAt = stats.lastSampleAtMs;
    final endedAt = stats.endedAtMs;
    return <String, Object?>{
      RideStatsPaths.distanceMeters: stats.distanceMeters,
      RideStatsPaths.movingTimeMs: stats.movingTimeMs,
      RideStatsPaths.maxSpeedMps: stats.maxSpeedMps,
      RideStatsPaths.sampleCount: stats.sampleCount,
      RideStatsPaths.startedAt: stats.startedAtMs,
      RideStatsPaths.updatedAt: updatedAt,
      RideStatsPaths.topSpeedAt: ?topSpeedAt,
      if (point != null) RideStatsPaths.lastLatitude: point.latitude,
      if (point != null) RideStatsPaths.lastLongitude: point.longitude,
      RideStatsPaths.lastSampleAt: ?lastSampleAt,
      if (endedAt != null) RideStatsPaths.finished: true,
      RideStatsPaths.endedAt: ?endedAt,
    };
  }

  static double _number(Object? value) => value is num ? value.toDouble() : 0;
}
