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
  static const String pausedMs = 'pausedMs';
  static const String pausedAt = 'pausedAt';

  // rideRoutes fields
  static const String polyline = 'polyline';
  static const String speeds = 'speeds';
  static const String times = 'times';

  // top-speed fields (rideStats, copied into the ride summary)
  static const String topSpeedLatitude = 'topSpeedLatitude';
  static const String topSpeedLongitude = 'topSpeedLongitude';
  static const String topSpeedDistance = 'topSpeedDistance';

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
    final topLat = value[RideStatsPaths.topSpeedLatitude];
    final topLng = value[RideStatsPaths.topSpeedLongitude];
    final topDistance = value[RideStatsPaths.topSpeedDistance];
    return RideStats(
      startedAtMs: startedAt.toInt(),
      distanceMeters: _number(value[RideStatsPaths.distanceMeters]),
      movingTimeMs: _number(value[RideStatsPaths.movingTimeMs]).toInt(),
      maxSpeedMps: _number(value[RideStatsPaths.maxSpeedMps]),
      topSpeedAtMs: topSpeedAt is num ? topSpeedAt.toInt() : null,
      topSpeedPoint: topLat is num && topLng is num
          ? GeoPoint(latitude: topLat.toDouble(), longitude: topLng.toDouble())
          : null,
      topSpeedDistanceMeters: topDistance is num ? topDistance.toDouble() : null,
      sampleCount: _number(value[RideStatsPaths.sampleCount]).toInt(),
      lastPoint: lat is num && lng is num
          ? GeoPoint(latitude: lat.toDouble(), longitude: lng.toDouble())
          : null,
      lastSampleAtMs: lastSampleAt is num ? lastSampleAt.toInt() : null,
      // Finished only counts when both the flag and its timestamp are there.
      endedAtMs: value[RideStatsPaths.finished] == true && endedAt is num
          ? endedAt.toInt()
          : null,
      pausedMs: _number(value[RideStatsPaths.pausedMs]).toInt(),
      pausedAtMs: switch (value[RideStatsPaths.pausedAt]) {
        final num at => at.toInt(),
        _ => null,
      },
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
      ...topSpeedFields(stats.topSpeedPoint, stats.topSpeedDistanceMeters),
      if (point != null) RideStatsPaths.lastLatitude: point.latitude,
      if (point != null) RideStatsPaths.lastLongitude: point.longitude,
      RideStatsPaths.lastSampleAt: ?lastSampleAt,
      if (endedAt != null) RideStatsPaths.finished: true,
      RideStatsPaths.endedAt: ?endedAt,
      RideStatsPaths.pausedMs: stats.pausedMs,
      // Written as null while riding, so resuming clears it.
      RideStatsPaths.pausedAt: stats.pausedAtMs,
    };
  }

  /// Where top speed was reached, as stored on the stats and the summary.
  static Map<String, Object?> topSpeedFields(GeoPoint? point, double? along) =>
      <String, Object?>{
        RideStatsPaths.topSpeedLatitude: ?point?.latitude,
        RideStatsPaths.topSpeedLongitude: ?point?.longitude,
        RideStatsPaths.topSpeedDistance: ?along,
      };

  static double _number(Object? value) => value is num ? value.toDouble() : 0;
}
