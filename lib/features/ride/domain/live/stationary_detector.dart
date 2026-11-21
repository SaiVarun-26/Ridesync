import 'dart:math' as math;

import '../location_fix.dart';

/// Tells when a rider has genuinely stopped riding: no meaningful movement
/// for a while, judged against GPS noise.
///
/// The rider's position when they stopped is kept as an anchor. A fix
/// counts as movement only when it is trustworthy and either lands well away
/// from the anchor (further than the fix's own uncertainty allows) or reports
/// a real riding speed. Jitter around a parked bike, a weak indoor fix or a
/// few metres of walking around never count; riding off always does.
///
/// Time with no fixes at all (GPS lost indoors) counts as stopped. Pure and
/// driven by the caller's clock.
class StationaryDetector {
  StationaryDetector({
    this.radiusMeters = 30,
    this.movingSpeedMps = 2.5,
    this.maxAccuracyMeters = 40,
  });

  /// Moving further than this from where the rider stopped (plus the fix's
  /// uncertainty) is movement.
  final double radiusMeters;

  /// A trustworthy fix at or above this speed is movement (9 km/h).
  final double movingSpeedMps;

  /// Fixes less accurate than this are ignored.
  final double maxAccuracyMeters;

  LocationFix? _anchor;
  int? _stillSinceMs;
  int? _lastMoveMs;

  /// Takes in a GPS fix. Returns whether it was movement.
  bool add(LocationFix fix) {
    final at = fix.timestamp.millisecondsSinceEpoch;
    final accuracy = fix.point.accuracyMeters ?? 15;
    if (accuracy > maxAccuracyMeters) {
      _stillSinceMs ??= at;
      return false;
    }
    final anchor = _anchor;
    if (anchor == null) {
      _anchor = fix;
      _stillSinceMs = at;
      return false;
    }
    final anchorAccuracy = anchor.point.accuracyMeters ?? 15;
    final distance = anchor.point.distanceMetersTo(fix.point);
    final allowance =
        radiusMeters + math.min(accuracy + anchorAccuracy, maxAccuracyMeters);
    final fast = (fix.speedMps ?? 0) >= movingSpeedMps && accuracy <= 25;
    if (distance > allowance || fast) {
      _anchor = fix;
      _stillSinceMs = at;
      _lastMoveMs = at;
      return true;
    }
    return false;
  }

  /// How long the rider has been still as of [nowMs]; zero before any fix.
  Duration stillFor(int nowMs) {
    final since = _stillSinceMs;
    if (since == null) return Duration.zero;
    return Duration(milliseconds: math.max(0, nowMs - since));
  }

  /// When the rider last moved, if they have.
  int? get lastMoveMs => _lastMoveMs;

  /// Starts counting stillness afresh from [nowMs] (the rider said they are
  /// still riding, or resumed after a pause).
  void reset(int nowMs) {
    _stillSinceMs = nowMs;
  }
}
