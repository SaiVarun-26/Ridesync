import 'dart:math' as math;

import '../../../history/domain/ride_details.dart';
import '../../../ride/domain/summary/ride_summary.dart';
import 'speed_profile.dart';

/// Everything worth knowing about one rider's part in a finished ride.
class RiderAnalytics {
  const RiderAnalytics({
    required this.rider,
    required this.name,
    required this.finishPosition,
    required this.contribution,
    required this.elapsed,
    this.speed,
  });

  final RiderRideSummary rider;

  /// The name the app shows for this rider.
  final String name;

  /// 1 for the first to finish (see [RideRankings.finishOrder]).
  final int finishPosition;

  /// This rider's share of the distance the whole group rode, 0 to 1.
  final double contribution;

  /// From this rider's start to their finish (or the ride's end).
  final Duration elapsed;

  /// How their speed behaved, when their route recorded speeds.
  final SpeedProfile? speed;

  String get uid => rider.uid;

  Duration get movingTime => rider.movingTime;

  /// Time on the ride spent not moving.
  Duration get stoppedTime {
    final stopped = elapsed.inMilliseconds - rider.movingTimeMs;
    return Duration(milliseconds: math.max(0, stopped));
  }

  /// Share of their time on the ride spent moving, 0 to 1.
  double get movingShare => elapsed.inMilliseconds <= 0
      ? 0
      : (rider.movingTimeMs / elapsed.inMilliseconds).clamp(0.0, 1.0);

  /// 0–100, when known.
  double? get consistency => speed?.consistency;
  double? get smoothness => speed?.smoothness;

  /// Whether this rider actually rode (had GPS and covered ground).
  bool get rode => rider.distanceMeters > 0;
}

/// Builds [RiderAnalytics] for every rider of a ride. Pure.
abstract final class RiderAnalyticsCalculator {
  /// One entry per rider, in finish order. [names] gives each rider's shown
  /// name by uid; anyone missing from it is called by their own name, or
  /// "Rider".
  static List<RiderAnalytics> forRide(
    RideDetails details, {
    Map<String, String> names = const {},
  }) {
    final summary = details.summary;
    final group = summary.group;
    final total = group.totalDistanceMeters;
    final ordered = RideRankings.finishOrder(summary.riders);
    return [
      for (final (index, rider) in ordered.indexed)
        RiderAnalytics(
          rider: rider,
          name: names[rider.uid] ?? _fallbackName(rider),
          finishPosition: index + 1,
          contribution: total > 0 ? rider.distanceMeters / total : 0,
          elapsed: Duration(
            milliseconds: math.max(
              0,
              (rider.endedAtMs ?? group.endedAtMs) -
                  (rider.startedAtMs ?? group.endedAtMs) -
                  // Paused time is not ride time.
                  rider.pausedMs,
            ),
          ),
          speed: _speedOf(details.routes[rider.uid]),
        ),
    ];
  }

  static String _fallbackName(RiderRideSummary rider) {
    final name = rider.displayName?.trim();
    return name == null || name.isEmpty ? 'Rider' : name;
  }

  static SpeedProfile? _speedOf(RiderRoute? route) {
    if (route == null || !route.hasSpeeds) return null;
    return SpeedAnalyzer.analyze(route.points, route.speedsMps);
  }
}
