import '../../../history/domain/ride_details.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../analysis/rider_analytics.dart';
import 'achievement.dart';

/// The achievements RideSync awards, with the thresholds that earn them. Each
/// rule is small and stands alone; [all] is the set every ride is checked
/// against.
abstract final class AchievementRules {
  static const List<AchievementRule> all = [
    LongestRideRule(),
    TopSpeedRecordRule(),
    BestFinishRule(),
    DistanceLeaderRule(),
    GroupLeaderRule(),
    FastestSprintRule(),
    LongestContinuousRule(),
    SmoothestRideRule(),
    ConsistentPaceRule(),
    NightRideRule(),
  ];

  static const AchievementEngine engine = AchievementEngine(all);
}

/// Your longest ride yet. Needs at least one earlier ride to beat.
class LongestRideRule implements AchievementRule {
  const LongestRideRule();

  static const double _minMeters = 1000;

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    final me = c.me;
    if (me == null || c.previousRides.isEmpty) return;
    final distance = me.rider.distanceMeters;
    if (distance < _minMeters) return;
    final best = c.previousRides
        .map((r) => r.distanceMeters)
        .reduce((a, b) => a > b ? a : b);
    if (distance <= best) return;
    yield Achievement(
      kind: AchievementKind.longestRide,
      title: 'Longest Ride',
      detail: '${RideFormat.distance(distance)}, your longest yet',
      priority: 100,
      holderUid: me.uid,
    );
  }
}

/// Your highest top speed yet. Needs at least one earlier ride to beat.
class TopSpeedRecordRule implements AchievementRule {
  const TopSpeedRecordRule();

  static const double _minMps = 15 / 3.6;

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    final me = c.me;
    if (me == null || c.previousRides.isEmpty) return;
    final top = me.rider.maxSpeedMps;
    if (top < _minMps) return;
    final best = c.previousRides
        .map((r) => r.maxSpeedMps)
        .reduce((a, b) => a > b ? a : b);
    if (top <= best) return;
    yield Achievement(
      kind: AchievementKind.topSpeedRecord,
      title: 'Highest Top Speed',
      detail: '${RideFormat.speed(top)}, a new personal best',
      priority: 95,
      holderUid: me.uid,
    );
  }
}

/// First to finish, in a group.
class BestFinishRule implements AchievementRule {
  const BestFinishRule();

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    if (!c.isGroup) return;
    final first = RideRankings.finishOrder(c.summary.riders).first;
    if (!first.finished || first.distanceMeters <= 0) return;
    yield Achievement(
      kind: AchievementKind.bestFinish,
      title: 'Best Finish',
      detail: 'First to finish the ride',
      priority: 80,
      holderUid: first.uid,
    );
  }
}

/// Rode the furthest, in a group, by a clear margin.
class DistanceLeaderRule implements AchievementRule {
  const DistanceLeaderRule();

  static const double _margin = 1.02;

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    final leader = _leader(c.riding, (r) => r.rider.distanceMeters, _margin);
    if (leader == null) return;
    yield Achievement(
      kind: AchievementKind.distanceLeader,
      title: 'Distance Leader',
      detail:
          'Rode the furthest: '
          '${RideFormat.distance(leader.rider.distanceMeters)}',
      priority: 70,
      holderUid: leader.uid,
    );
  }
}

/// Set the group's pace: the highest average moving speed, by a clear margin.
class GroupLeaderRule implements AchievementRule {
  const GroupLeaderRule();

  static const double _margin = 1.03;

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    final leader = _leader(c.riding, (r) => r.rider.averageSpeedMps, _margin);
    if (leader == null) return;
    yield Achievement(
      kind: AchievementKind.groupLeader,
      title: 'Group Leader',
      detail:
          'Set the pace at ${RideFormat.speed(leader.rider.averageSpeedMps)}',
      priority: 65,
      holderUid: leader.uid,
    );
  }
}

/// The quickest short burst. In a group it goes to the fastest sprinter; solo
/// it has to be a real burst well above the ride's average.
class FastestSprintRule implements AchievementRule {
  const FastestSprintRule();

  static const double _minMps = 20 / 3.6;
  static const double _soloOverAverage = 1.25;

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    final best = _best(c.riding, (r) => r.speed?.sprintSpeedMps);
    if (best == null) return;
    final sprint = best.speed!.sprintSpeedMps;
    if (sprint < _minMps) return;
    if (!c.isGroup &&
        sprint < best.speed!.averageMovingSpeedMps * _soloOverAverage) {
      return;
    }
    yield Achievement(
      kind: AchievementKind.fastestSprint,
      title: 'Fastest Sprint',
      detail: 'Hit ${RideFormat.speed(sprint)} over 200 m',
      priority: 60,
      holderUid: best.uid,
    );
  }
}

/// The longest stretch ridden without slowing to a crawl.
class LongestContinuousRule implements AchievementRule {
  const LongestContinuousRule();

  static const double _groupMinMeters = 3000;
  static const double _soloMinMeters = 5000;

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    final best = _best(c.riding, (r) => r.speed?.longestContinuousMeters);
    if (best == null) return;
    final meters = best.speed!.longestContinuousMeters;
    if (meters < (c.isGroup ? _groupMinMeters : _soloMinMeters)) return;
    yield Achievement(
      kind: AchievementKind.longestContinuous,
      title: 'Longest Continuous Ride',
      detail: '${RideFormat.distance(meters)} without stopping',
      priority: 50,
      holderUid: best.uid,
    );
  }
}

/// The smoothest riding of the group, or a very smooth solo ride.
class SmoothestRideRule implements AchievementRule {
  const SmoothestRideRule();

  static const double _groupMin = 70;
  static const double _soloMin = 80;

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    final best = _best(c.riding, (r) => r.smoothness);
    if (best == null) return;
    final score = best.smoothness!;
    if (score < (c.isGroup ? _groupMin : _soloMin)) return;
    yield Achievement(
      kind: AchievementKind.smoothestRide,
      title: 'Smoothest Ride',
      detail: 'Smoothness ${score.round()}/100',
      priority: 40,
      holderUid: best.uid,
    );
  }
}

/// The most even pace of the group, or a very even solo ride.
class ConsistentPaceRule implements AchievementRule {
  const ConsistentPaceRule();

  static const double _groupMin = 65;
  static const double _soloMin = 75;

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    final best = _best(c.riding, (r) => r.consistency);
    if (best == null) return;
    final score = best.consistency!;
    if (score < (c.isGroup ? _groupMin : _soloMin)) return;
    yield Achievement(
      kind: AchievementKind.consistentPace,
      title: 'Most Consistent Pace',
      detail: 'Consistency ${score.round()}/100',
      priority: 35,
      holderUid: best.uid,
    );
  }
}

/// Rode after dark: the weather said it was night, or (without weather) the
/// ride started in the evening or the small hours.
class NightRideRule implements AchievementRule {
  const NightRideRule();

  static const int _eveningHour = 19;
  static const int _morningHour = 5;

  @override
  Iterable<Achievement> evaluate(AchievementContext c) sync* {
    final group = c.summary.group;
    final isDay = c.weather?.isDay;
    final hour = DateTime.fromMillisecondsSinceEpoch(group.startedAtMs).hour;
    final night =
        isDay == false ||
        (isDay == null && (hour >= _eveningHour || hour < _morningHour));
    if (!night || group.totalDistanceMeters <= 0) return;
    yield const Achievement(
      kind: AchievementKind.nightRide,
      title: 'Night Ride',
      detail: 'Rode after dark',
      priority: 20,
    );
  }
}

/// The rider with the highest [value] among those who have one.
RiderAnalytics? _best(
  List<RiderAnalytics> riders,
  double? Function(RiderAnalytics) value,
) {
  RiderAnalytics? best;
  double? bestValue;
  for (final r in riders) {
    final v = value(r);
    if (v == null) continue;
    if (bestValue == null || v > bestValue) {
      best = r;
      bestValue = v;
    }
  }
  return best;
}

/// In a group, the rider whose [value] beats everyone else's by [margin]
/// (a ratio); `null` when it is too close to call or the ride is solo.
RiderAnalytics? _leader(
  List<RiderAnalytics> riders,
  double Function(RiderAnalytics) value,
  double margin,
) {
  if (riders.length < 2) return null;
  final sorted = [...riders]..sort((a, b) => value(b).compareTo(value(a)));
  final top = value(sorted[0]);
  final next = value(sorted[1]);
  if (top <= 0 || top < next * margin) return null;
  return sorted.first;
}
