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
    this.topSpeedPoint,
    this.topSpeedDistanceMeters,
    this.sampleCount = 0,
    this.lastPoint,
    this.lastSampleAtMs,
    this.endedAtMs,
    this.pausedMs = 0,
    this.pausedAtMs,
  });

  /// Time spent paused by the rider (Pause Ride), in finished pauses. Kept
  /// apart from stopped time: it counts as neither riding nor stopping.
  final int pausedMs;

  /// When the current pause began (epoch millis); `null` while riding.
  final int? pausedAtMs;

  /// Whether the rider has paused the ride.
  bool get isPaused => pausedAtMs != null;

  /// All paused time as of [nowMs], the current pause included.
  int pausedTotalMs(int nowMs) {
    final at = pausedAtMs;
    if (at == null) return pausedMs;
    final until = math.min(nowMs, endedAtMs ?? nowMs);
    return pausedMs + math.max(0, until - at);
  }

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

  /// Where [maxSpeedMps] was reached, and how far into the ride, if known.
  final GeoPoint? topSpeedPoint;
  final double? topSpeedDistanceMeters;

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

  /// Ride time since the start as of [nowMs]: stops included, pauses not, so
  /// the ride's clock stands still while it is paused. Once the ride is
  /// finished it stops at [endedAtMs].
  Duration elapsed(int nowMs) => Duration(
    milliseconds: math.max(
      0,
      math.min(nowMs, endedAtMs ?? nowMs) - startedAtMs - pausedTotalMs(nowMs),
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
    GeoPoint? topSpeedPoint,
    double? topSpeedDistanceMeters,
    int? sampleCount,
    GeoPoint? lastPoint,
    int? lastSampleAtMs,
    int? endedAtMs,
    int? pausedMs,
    int? pausedAtMs,
    bool clearPausedAt = false,
  }) {
    return RideStats(
      pausedMs: pausedMs ?? this.pausedMs,
      pausedAtMs: clearPausedAt ? null : (pausedAtMs ?? this.pausedAtMs),
      startedAtMs: startedAtMs,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      movingTimeMs: movingTimeMs ?? this.movingTimeMs,
      maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
      topSpeedAtMs: topSpeedAtMs ?? this.topSpeedAtMs,
      topSpeedPoint: topSpeedPoint ?? this.topSpeedPoint,
      topSpeedDistanceMeters:
          topSpeedDistanceMeters ?? this.topSpeedDistanceMeters,
      sampleCount: sampleCount ?? this.sampleCount,
      lastPoint: lastPoint ?? this.lastPoint,
      lastSampleAtMs: lastSampleAtMs ?? this.lastSampleAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
    );
  }
}
