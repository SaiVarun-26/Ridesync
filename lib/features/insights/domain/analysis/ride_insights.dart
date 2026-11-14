import 'dart:math' as math;

import '../../../ride/domain/live/ride_format.dart';
import 'rider_analytics.dart';
import 'route_profile.dart';
import 'speed_profile.dart';

/// What an insight is about. Also picks its icon.
enum InsightKind {
  smoothness,
  consistency,
  intensity,
  fastestSegment,
  slowestSegment,
  mostActive,
  closestPair,
  paceStability,
}

/// One easy-to-scan fact about a ride: a short title, the figure, and a line
/// of context.
class RideInsight {
  const RideInsight({
    required this.kind,
    required this.title,
    required this.value,
    required this.detail,
    this.score,
  });

  final InsightKind kind;
  final String title;

  /// The headline figure: "86", "31 km/h", "Sai".
  final String value;
  final String detail;

  /// 0–100 when the insight is a score, for drawing a small meter.
  final double? score;
}

/// Picks the insights worth showing for a ride. Pure.
///
/// Only insights backed by real data are returned: a ride recorded without
/// speeds simply has fewer, rather than empty or guessed ones.
abstract final class InsightCalculator {
  /// The insights for a ride seen by [myUid], most personal first.
  static List<RideInsight> forRide({
    required List<RiderAnalytics> riders,
    required String? myUid,
    RouteProfile? route,
  }) {
    final mine = _find(riders, myUid);
    final speed = mine?.speed ?? _best(riders);
    final insights = <RideInsight>[];

    if (speed != null) {
      insights
        ..add(
          RideInsight(
            kind: InsightKind.smoothness,
            title: 'Smoothness',
            value: '${speed.smoothness.round()}',
            detail: _smoothnessNote(speed.smoothness),
            score: speed.smoothness,
          ),
        )
        ..add(
          RideInsight(
            kind: InsightKind.consistency,
            title: 'Speed consistency',
            value: '${speed.consistency.round()}',
            detail: _consistencyNote(speed.consistency),
            score: speed.consistency,
          ),
        );
    }
    if (route != null) {
      insights.add(
        RideInsight(
          kind: InsightKind.intensity,
          title: 'Route intensity',
          value: route.intensity.label,
          detail:
              '${route.turnCount} turns · '
              '${RideFormat.distance(route.distanceMeters)}',
          score: route.intensityScore,
        ),
      );
    }
    final fastest = speed?.fastest;
    if (fastest != null) {
      insights.add(
        RideInsight(
          kind: InsightKind.fastestSegment,
          title: 'Fastest stretch',
          value: RideFormat.speed(fastest.averageSpeedMps),
          detail: _where(fastest),
        ),
      );
    }
    final slowest = speed?.slowest;
    if (slowest != null && slowest != fastest) {
      insights.add(
        RideInsight(
          kind: InsightKind.slowestSegment,
          title: 'Slowest stretch',
          value: RideFormat.speed(slowest.averageSpeedMps),
          detail: _where(slowest),
        ),
      );
    }

    final riding = [
      for (final r in riders)
        if (r.rode) r,
    ];
    if (riding.length >= 2) {
      final active = riding.reduce(
        (a, b) => b.movingShare > a.movingShare ? b : a,
      );
      insights.add(
        RideInsight(
          kind: InsightKind.mostActive,
          title: 'Most active rider',
          value: nameOf(active),
          detail: '${(active.movingShare * 100).round()}% of the ride moving',
        ),
      );

      final pair = _closestPair(riding);
      if (pair != null) {
        insights.add(
          RideInsight(
            kind: InsightKind.closestPair,
            title: 'Closest gap',
            value: RideFormat.distance(pair.$3),
            detail: '${nameOf(pair.$1)} and ${nameOf(pair.$2)}',
          ),
        );
      }

      final stability = paceStability(riding);
      if (stability != null) {
        insights.add(
          RideInsight(
            kind: InsightKind.paceStability,
            title: 'Group pace stability',
            value: '${stability.round()}',
            detail: stability >= 75
                ? 'The group rode as one'
                : stability >= 50
                ? 'A fairly even group pace'
                : 'The group spread out',
            score: stability,
          ),
        );
      }
    }
    return insights;
  }

  /// 0–100: how close the riders' average speeds were. `null` with fewer
  /// than two riders who moved.
  static double? paceStability(List<RiderAnalytics> riders) {
    final speeds = [
      for (final r in riders)
        if (r.rider.averageSpeedMps > 0) r.rider.averageSpeedMps,
    ];
    if (speeds.length < 2) return null;
    final mean = speeds.reduce((a, b) => a + b) / speeds.length;
    if (mean <= 0) return null;
    var variance = 0.0;
    for (final s in speeds) {
      variance += (s - mean) * (s - mean);
    }
    final cv = math.sqrt(variance / speeds.length) / mean;
    return 100 * (1 - cv / 0.5).clamp(0.0, 1.0);
  }

  /// The two riders whose distances were closest, and the difference. The
  /// routes carry no times, so this is the gap in distance covered, not a
  /// live gap on the road.
  static (RiderAnalytics, RiderAnalytics, double)? _closestPair(
    List<RiderAnalytics> riders,
  ) {
    final sorted = [
      ...riders,
    ]..sort((a, b) => a.rider.distanceMeters.compareTo(b.rider.distanceMeters));
    (RiderAnalytics, RiderAnalytics, double)? best;
    for (var i = 1; i < sorted.length; i++) {
      final gap =
          sorted[i].rider.distanceMeters - sorted[i - 1].rider.distanceMeters;
      if (best == null || gap < best.$3) best = (sorted[i], sorted[i - 1], gap);
    }
    return best;
  }

  /// The name shown for a rider.
  static String nameOf(RiderAnalytics rider) => rider.name;

  static RiderAnalytics? _find(List<RiderAnalytics> riders, String? uid) {
    for (final r in riders) {
      if (r.uid == uid) return r;
    }
    return null;
  }

  /// The furthest rider with a speed profile, to describe the ride when this
  /// rider has none.
  static SpeedProfile? _best(List<RiderAnalytics> riders) {
    SpeedProfile? best;
    var furthest = -1.0;
    for (final r in riders) {
      final s = r.speed;
      if (s != null && r.rider.distanceMeters > furthest) {
        best = s;
        furthest = r.rider.distanceMeters;
      }
    }
    return best;
  }

  static String _where(RouteSegment segment) =>
      'km ${(segment.startMeters / 1000).toStringAsFixed(1)}'
      '–${(segment.endMeters / 1000).toStringAsFixed(1)}';

  static String _smoothnessNote(double score) => switch (score) {
    >= 80 => 'Flowing, with gentle speed changes',
    >= 60 => 'Mostly smooth riding',
    >= 40 => 'Some sharp slowdowns',
    _ => 'Lots of stop-and-go',
  };

  static String _consistencyNote(double score) => switch (score) {
    >= 75 => 'A very even pace',
    >= 50 => 'A fairly steady pace',
    _ => 'Pace varied a lot',
  };
}
