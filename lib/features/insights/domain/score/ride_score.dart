import 'dart:math' as math;

/// A ride's score out of 100, with a word for it.
class RideScore {
  const RideScore(this.value);

  final int value;

  String get label => switch (value) {
    >= 85 => 'Outstanding',
    >= 70 => 'Great ride',
    >= 55 => 'Solid ride',
    >= 40 => 'Easy-going',
    _ => 'Warm-up',
  };
}

/// Scores a ride from 0 to 100. Pure.
///
/// The score rewards riding well more than riding far: how smooth and even
/// the riding was counts for half, how much ground was covered for about a
/// fifth, and how well the group stayed together (or, solo, how much of the
/// ride was spent moving) and whether it was finished make up the rest.
/// Missing data (rides recorded before speeds were saved) is filled with a
/// neutral value, so old rides still get a fair score.
abstract final class RideScoreCalculator {
  static const double _neutral = 0.6;

  /// Distance at which the distance part is full.
  static const double _fullKm = 40;

  /// Rides shorter than this are capped low: too short to judge.
  static const double _shortMeters = 500;
  static const int _shortCap = 35;

  static RideScore score({
    required double distanceMeters,
    double? smoothness,
    double? consistency,
    double? cohesion,
    double? movingShare,
    bool finished = true,
  }) {
    final smooth = (smoothness ?? _neutral * 100) / 100;
    final even = (consistency ?? _neutral * 100) / 100;
    final km = math.max(0.0, distanceMeters / 1000);
    final distance = (math.log(1 + km) / math.log(1 + _fullKm)).clamp(0.0, 1.0);
    final together = (cohesion ?? (movingShare ?? _neutral) * 100) / 100;
    final completion = finished ? 1.0 : 0.5;
    final raw =
        100 *
        (0.28 * smooth +
            0.24 * even +
            0.22 * distance +
            0.16 * together.clamp(0.0, 1.0) +
            0.10 * completion);
    var value = raw.round().clamp(0, 100);
    if (distanceMeters < _shortMeters) value = math.min(value, _shortCap);
    return RideScore(value);
  }
}
