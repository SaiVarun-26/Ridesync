import 'dart:math' as math;

/// Decides whether the rider has left the planned line, without flapping.
///
/// A single bad fix never counts: the rider has to be clearly away from the
/// route for several fixes in a row and for a few seconds before they are
/// called off route, and clearly back on it before the warning clears. Both
/// thresholds widen with poor GPS accuracy, so a weak signal near the route is
/// not mistaken for leaving it. Pure Dart, driven by the caller's clock.
class OffRouteDetector {
  OffRouteDetector({
    this.leaveMeters = 45,
    this.rejoinMeters = 25,
    this.confirmFixes = 3,
    this.confirmTime = const Duration(seconds: 4),
    this.rejoinFixes = 2,
  });

  /// Cross-track distance beyond which the rider may be leaving the route.
  final double leaveMeters;

  /// Cross-track distance within which they are back on it.
  final double rejoinMeters;

  /// Fixes in a row, and time, beyond [leaveMeters] before calling it.
  final int confirmFixes;
  final Duration confirmTime;

  /// Fixes in a row within [rejoinMeters] before clearing it.
  final int rejoinFixes;

  /// Accuracy (metres) widens the thresholds by this share, up to the caps.
  static const double _accuracyShare = 1.0;
  static const double _maxLeaveMeters = 90;
  static const double _maxRejoinSlack = 15;

  bool _offRoute = false;
  int _awayCount = 0;
  int? _awaySinceMs;
  int _backCount = 0;

  bool get isOffRoute => _offRoute;

  /// Takes one fix [offsetMeters] from the route at [timeMs] and returns
  /// whether the rider is now off route.
  bool update(double offsetMeters, {double? accuracyMeters, required int timeMs}) {
    final accuracy = accuracyMeters ?? 0;
    final leave = math.min(
      _maxLeaveMeters,
      math.max(leaveMeters, accuracy * _accuracyShare + rejoinMeters),
    );
    final rejoin =
        rejoinMeters + math.min(_maxRejoinSlack, accuracy * 0.5);

    if (!_offRoute) {
      if (offsetMeters > leave) {
        _awayCount++;
        _awaySinceMs ??= timeMs;
        if (_awayCount >= confirmFixes &&
            timeMs - _awaySinceMs! >= confirmTime.inMilliseconds) {
          _offRoute = true;
          _backCount = 0;
        }
      } else {
        _awayCount = 0;
        _awaySinceMs = null;
      }
    } else {
      if (offsetMeters <= rejoin) {
        _backCount++;
        if (_backCount >= rejoinFixes) {
          _offRoute = false;
          _awayCount = 0;
          _awaySinceMs = null;
        }
      } else {
        _backCount = 0;
      }
    }
    return _offRoute;
  }
}
