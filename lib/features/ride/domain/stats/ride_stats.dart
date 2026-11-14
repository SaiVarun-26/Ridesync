import 'dart:math' as math;

import '../geo_point.dart';

/// A rider's statistics for the current ride, accumulated from their own GPS
/// fixes and saved continuously so a crash or reconnect never resets them.
///
/// Immutable; [RideStatsTracker] produces each new value. The last accepted
/// point and time are part of the value so that a restored ride can continue
/// from exactly where it stopped.
class RideStats {
  const RideStats({
    required this.startedAtMs,
    this.distanceMeters = 0,
    this.movingTimeMs = 0,
    this.maxSpeedMps = 0,
    this.topSpeedAtMs,
    this.sampleCount = 0,
    this.lastPoint,
    this.lastSampleAtMs,
    this.endedAtMs,
  });

  /// When the ride started for this rider (epoch millis).
  final int startedAtMs;

  /// When this rider's ride was frozen at End Ride (epoch millis). `null`
  /// while the ride is still going.
  final int? endedAtMs;

  /// Whether this rider's statistics are final.
  bool get isFinished => endedAtMs != null;

  /// Distance travelled while moving.
  final double distanceMeters;

  /// Time spent actually moving, excluding stops.
  final int movingTimeMs;

  /// Highest ground speed recorded.
  final double maxSpeedMps;

  /// When [maxSpeedMps] was reached (epoch millis), if it has been.
  final int? topSpeedAtMs;

  /// Number of GPS fixes that passed quality checks.
  final int sampleCount;

  /// The last accepted position, used to continue after a restore.
  final GeoPoint? lastPoint;

  /// When [lastPoint] was recorded (epoch millis).
  final int? lastSampleAtMs;

  /// Moving time as a [Duration].
  Duration get movingTime => Duration(milliseconds: movingTimeMs);

  /// Average speed while moving, in meters per second. Zero before any
  /// movement.
  double get averageSpeedMps =>
      movingTimeMs <= 0 ? 0 : distanceMeters / (movingTimeMs / 1000);

  /// Total time since the ride started, including stops, as of [nowMs]. Once
  /// the ride is finished it stops at [endedAtMs].
  Duration elapsed(int nowMs) => Duration(
    milliseconds: math.max(
      0,
      math.min(nowMs, endedAtMs ?? nowMs) - startedAtMs,
    ),
  );

  /// Time spent stopped so far: everything in [elapsed] that was not moving.
  Duration stoppedTime(int nowMs) {
    final stopped = elapsed(nowMs).inMilliseconds - movingTimeMs;
    return Duration(milliseconds: math.max(0, stopped));
  }

  /// A copy with the given fields replaced.
  RideStats copyWith({
    double? distanceMeters,
    int? movingTimeMs,
    double? maxSpeedMps,
    int? topSpeedAtMs,
    int? sampleCount,
    GeoPoint? lastPoint,
    int? lastSampleAtMs,
    int? endedAtMs,
  }) {
    return RideStats(
      startedAtMs: startedAtMs,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      movingTimeMs: movingTimeMs ?? this.movingTimeMs,
      maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
      topSpeedAtMs: topSpeedAtMs ?? this.topSpeedAtMs,
      sampleCount: sampleCount ?? this.sampleCount,
      lastPoint: lastPoint ?? this.lastPoint,
      lastSampleAtMs: lastSampleAtMs ?? this.lastSampleAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
    );
  }
}
