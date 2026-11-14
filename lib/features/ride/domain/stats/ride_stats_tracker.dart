import 'dart:math' as math;

import '../location_fix.dart';
import 'ride_stats.dart';

/// Turns a stream of GPS fixes into [RideStats], rejecting noise.
///
/// Pure Dart with no clock of its own: every decision uses the fix's own
/// timestamp, so behaviour is deterministic and the same on a restored ride.
///
/// Rules:
/// - Fixes less accurate than [maxAccuracyMeters] are ignored.
/// - A rider counts as moving at or above [movingSpeedMps] and after at least
///   [minSegmentMeters] of travel; slower creep and stationary GPS drift add
///   no distance, moving time, or top speed.
/// - An implied speed above [maxPlausibleSpeedMps] is a GPS glitch and the fix
///   is dropped.
/// - After a gap longer than [resumeGap] (app killed, tunnel, long stop) the
///   next fix starts a new segment: no distance is invented across the gap.
/// - Moving time is credited for the time the segment actually took to ride
///   at the fix's speed, never for the whole gap since the last fix. GPS only
///   reports after real movement, so the first fix after a stop arrives after
///   a long gap; crediting that gap would count the stop as riding and drag
///   the average speed down. The credit is also capped at
///   [maxMovingCreditMs].
/// - A top speed is only accepted if it is physically reachable from the
///   previous moving speed (at most [maxAccelerationMps2]), which rejects
///   single-fix GPS speed spikes.
///
/// Average speed is distance over moving time (see
/// [RideStats.averageSpeedMps]), so stops never lower it; stopped time is the
/// rest of the ride's elapsed time ([RideStats.stoppedTime]).
class RideStatsTracker {
  RideStatsTracker({RideStats? initial}) : _stats = initial;

  /// Allowance on top of distance ÷ speed when crediting moving time, for
  /// curves (GPS distance is a straight chord) and speed changes within the
  /// segment.
  static const double movingCreditSlack = 1.25;

  /// The fastest believable change in speed between two fixes, in m/s². Well
  /// beyond any bicycle, car or motorcycle; a GPS spike is far beyond it.
  static const double maxAccelerationMps2 = 12;

  /// Extra headroom on [maxAccelerationMps2] for the noise in any one reading.
  static const double accelerationToleranceMps = 3;

  /// Speed of the last moving fix, to judge whether a new top speed is real.
  /// Not saved: after a restore the first moving fix only sets it.
  double? _lastMovingSpeedMps;

  static const double maxAccuracyMeters = 30;
  static const double movingSpeedMps = 1;
  static const double minSegmentMeters = 3;
  static const double maxPlausibleSpeedMps = 150;
  static const Duration resumeGap = Duration(minutes: 2);
  static const int maxMovingCreditMs = 15000;

  RideStats? _stats;

  /// The statistics so far, or `null` before the first accepted fix.
  RideStats? get stats => _stats;

  /// Continues from previously saved [stats].
  void restore(RideStats stats) => _stats = stats;

  /// Folds [fix] into the statistics. Returns whether anything changed.
  bool add(LocationFix fix) {
    final accuracy = fix.point.accuracyMeters;
    if (accuracy != null && accuracy > maxAccuracyMeters) return false;

    final point = fix.point;
    final atMs = fix.timestamp.millisecondsSinceEpoch;
    final current = _stats;

    if (current == null) {
      _stats = RideStats(
        startedAtMs: atMs,
        sampleCount: 1,
        lastPoint: point,
        lastSampleAtMs: atMs,
      );
      return true;
    }

    final lastPoint = current.lastPoint;
    final lastAtMs = current.lastSampleAtMs;
    final sampled = current.copyWith(
      sampleCount: current.sampleCount + 1,
      lastPoint: point,
      lastSampleAtMs: atMs,
    );
    if (lastPoint == null || lastAtMs == null) {
      _stats = sampled;
      return true;
    }

    final dtMs = atMs - lastAtMs;
    if (dtMs <= 0) return false;
    if (dtMs > resumeGap.inMilliseconds) {
      _stats = sampled;
      return true;
    }

    final meters = lastPoint.distanceMetersTo(point);
    final impliedSpeed = meters / (dtMs / 1000);
    if (impliedSpeed > maxPlausibleSpeedMps) return false;

    final speed = fix.speedMps ?? impliedSpeed;
    final moving = speed >= movingSpeedMps && meters >= minSegmentMeters;
    if (!moving) {
      _lastMovingSpeedMps = null;
      _stats = sampled;
      return true;
    }

    final previousSpeed = _lastMovingSpeedMps;
    _lastMovingSpeedMps = speed;
    final reachable =
        previousSpeed != null &&
        speed <=
            previousSpeed +
                maxAccelerationMps2 * dtMs / 1000 +
                accelerationToleranceMps;
    final isTopSpeed =
        reachable &&
        speed > current.maxSpeedMps &&
        speed <= maxPlausibleSpeedMps;
    _stats = sampled.copyWith(
      distanceMeters: current.distanceMeters + meters,
      movingTimeMs: current.movingTimeMs + movingCreditMs(meters, speed, dtMs),
      maxSpeedMps: isTopSpeed ? speed : null,
      topSpeedAtMs: isTopSpeed ? atMs : null,
    );
    return true;
  }

  /// Moving time to credit for riding [meters] at [speedMps], where the fix
  /// arrived [dtMs] after the previous one: the time the segment takes at
  /// that speed (with [movingCreditSlack]), never more than the gap itself or
  /// [maxMovingCreditMs].
  static int movingCreditMs(double meters, double speedMps, int dtMs) {
    final ridingMs = (meters / speedMps * 1000 * movingCreditSlack).round();
    return math.min(math.min(dtMs, ridingMs), maxMovingCreditMs);
  }
}
