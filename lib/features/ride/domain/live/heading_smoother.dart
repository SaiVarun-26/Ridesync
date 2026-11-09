import 'dart:math' as math;

/// Turns noisy, irregular compass headings into a calm rotation for the
/// navigation camera.
///
/// Three rules keep the map from spinning or jittering:
/// - **Freeze when there is no heading.** The caller passes `null` while the
///   rider is stationary (GPS heading is noise then); the rotation holds its
///   last value.
/// - **Deadband.** Tiny changes are ignored until the heading drifts past
///   [deadbandDegrees], so a steady road does not shimmer the map.
/// - **Smooth, rate-limited turning.** Rotation eases toward the target with a
///   first-order filter and never turns faster than [maxDegreesPerSecond], so a
///   U-turn or a long pause followed by a new heading sweeps rather than snaps.
///
/// Angles are compass degrees (0–360, clockwise from north) and always take the
/// shortest way round. Pure Dart, driven by the caller's clock.
class HeadingSmoother {
  HeadingSmoother({
    this.timeConstant = const Duration(milliseconds: 700),
    this.maxDegreesPerSecond = 90,
    this.deadbandDegrees = 2,
  });

  /// How quickly rotation catches up; larger is calmer.
  final Duration timeConstant;

  /// Hard limit on rotation speed.
  final double maxDegreesPerSecond;

  /// Heading changes smaller than this are ignored while at rest.
  final double deadbandDegrees;

  /// Longest time step used in one update. After an idle gap the filter
  /// continues gently instead of jumping.
  static const Duration _maxStep = Duration(milliseconds: 100);

  /// Step used for the very first update.
  static const Duration _firstStep = Duration(milliseconds: 16);

  /// Once this close to the target, rotation is considered settled.
  static const double _settledDegrees = 0.5;

  double? _current;
  Duration? _lastStep;
  bool _settling = false;

  /// The current smoothed heading, or `null` before any heading was seen.
  double? get current => _current;

  /// Whether rotation is still moving toward its target.
  bool get isSettling => _settling;

  /// Advances the smoothing to [now] toward [target] and returns the smoothed
  /// heading. A `null` [target] freezes rotation.
  double? step(double? target, Duration now) {
    final dt = _elapsed(now);
    _lastStep = now;

    if (target == null) {
      _settling = false;
      return _current;
    }
    final goal = _normalize(target);
    final current = _current;
    if (current == null) {
      _current = goal;
      _settling = false;
      return goal;
    }

    final delta = _shortestDelta(goal, current);
    if (delta.abs() < deadbandDegrees && !_settling) return current;

    final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
    final alpha =
        1 - math.exp(-dt.inMicroseconds / timeConstant.inMicroseconds);
    final limit = maxDegreesPerSecond * seconds;
    final change = (delta * alpha).clamp(-limit, limit);

    final next = _normalize(current + change);
    _current = next;
    _settling = (delta - change).abs() > _settledDegrees;
    return next;
  }

  Duration _elapsed(Duration now) {
    final last = _lastStep;
    if (last == null) return _firstStep;
    final dt = now - last;
    if (dt.isNegative) return Duration.zero;
    return dt > _maxStep ? _maxStep : dt;
  }

  /// Signed shortest rotation from [from] to [to], in (-180, 180].
  static double _shortestDelta(double to, double from) =>
      ((to - from + 540) % 360) - 180;

  static double _normalize(double degrees) => degrees % 360;
}
