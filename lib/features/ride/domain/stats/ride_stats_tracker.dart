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
/// - Moving time credit per fix is capped at [maxMovingCreditMs], so a sparse
///   fix cannot inflate it.
class RideStatsTracker {
  RideStatsTracker({RideStats? initial}) : _stats = initial;

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
      _stats = sampled;
      return true;
    }

    final isTopSpeed =
        speed > current.maxSpeedMps && speed <= maxPlausibleSpeedMps;
    _stats = sampled.copyWith(
      distanceMeters: current.distanceMeters + meters,
      movingTimeMs: current.movingTimeMs + math.min(dtMs, maxMovingCreditMs),
      maxSpeedMps: isTopSpeed ? speed : null,
      topSpeedAtMs: isTopSpeed ? atMs : null,
    );
    return true;
  }
}
