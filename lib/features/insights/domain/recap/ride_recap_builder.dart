import '../../../history/domain/ride_details.dart';
import '../achievements/achievement.dart';
import '../achievements/achievement_rules.dart';
import '../analysis/ride_insights.dart';
import '../analysis/rider_analytics.dart';
import '../analysis/route_profile.dart';
import '../score/ride_score.dart';
import 'recap_narrator.dart';
import 'ride_recap.dart';

/// Turns a finished ride into a [RideRecap]. Pure and synchronous, so it can
/// run in a background isolate and be tested without Flutter.
class RideRecapBuilder {
  const RideRecapBuilder({
    this.narrator = const RuleBasedRecapNarrator(),
    this.achievements = AchievementRules.engine,
  });

  /// Writes the recap sentence. Swap for a different narrator to change the
  /// voice without touching anything else.
  final RecapNarrator narrator;

  final AchievementEngine achievements;

  RideRecap build(RecapInput input) {
    final details = input.details;
    final summary = details.summary;
    final myUid = input.myUid;
    final riders = RiderAnalyticsCalculator.forRide(
      details,
      names: input.riderNames,
    );

    RiderAnalytics? me;
    for (final r in riders) {
      if (r.uid == myUid) me = r;
    }

    // The route to analyse: this rider's own, else the furthest rider's.
    final routeUid = details.routes.containsKey(myUid)
        ? myUid
        : _furthestWithRoute(riders, details);
    final routeData = routeUid == null ? null : details.routes[routeUid];
    final routeSpeed = riders
        .where((r) => r.uid == routeUid)
        .map((r) => r.speed)
        .firstOrNull;
    final route = routeData == null
        ? null
        : RouteAnalyzer.analyze(
            routeData.points,
            averageMovingSpeedMps: routeSpeed?.averageMovingSpeedMps,
            slowdowns: routeSpeed?.slowdowns ?? 0,
          );

    final previous = [
      for (final p in input.previousRides)
        if (p.code != summary.roomCode && p.endedAtMs < summary.group.endedAtMs)
          p,
    ];
    final earned = achievements.evaluate(
      AchievementContext(
        summary: summary,
        riders: riders,
        myUid: myUid,
        previousRides: previous,
        route: route,
        weather: input.weather,
      ),
    );

    final insights = InsightCalculator.forRide(
      riders: riders,
      myUid: myUid,
      route: route,
    );
    final riding = [
      for (final r in riders)
        if (r.rode) r,
    ];
    final stability = InsightCalculator.paceStability(riding);
    final mySpeed = me?.speed;

    final score = RideScoreCalculator.score(
      distanceMeters:
          me?.rider.distanceMeters ?? summary.group.longestDistanceMeters,
      smoothness: mySpeed?.smoothness,
      consistency: mySpeed?.consistency,
      cohesion: riding.length >= 2 ? stability : null,
      movingShare: me?.movingShare,
      finished: me?.rider.finished ?? true,
    );

    final facts = RecapFacts(
      startedAt: DateTime.fromMillisecondsSinceEpoch(summary.group.startedAtMs),
      riderCount: summary.group.riderCount,
      distanceMeters:
          me?.rider.distanceMeters ?? summary.group.longestDistanceMeters,
      durationMs: summary.group.durationMs,
      averageSpeedMps: summary.group.averageSpeedMps,
      smoothness: mySpeed?.smoothness ?? routeSpeed?.smoothness,
      consistency: mySpeed?.consistency ?? routeSpeed?.consistency,
      paceStability: riding.length >= 2 ? stability : null,
      topSpeedFraction: (mySpeed ?? routeSpeed)?.topSpeedFraction,
      route: route,
      weather: input.weather,
    );

    return RideRecap(
      summary: summary,
      myUid: myUid,
      score: score,
      sentence: narrator.narrate(facts),
      facts: facts,
      achievements: earned,
      insights: insights,
      riders: riders,
      route: route,
      weather: input.weather,
      mySpeed: mySpeed,
      routePoints: routeData?.points ?? const [],
      routeSpeedsMps: routeData?.speedsMps ?? const [],
    );
  }

  static String? _furthestWithRoute(
    List<RiderAnalytics> riders,
    RideDetails details,
  ) {
    String? best;
    var furthest = -1.0;
    for (final r in riders) {
      if (details.routes.containsKey(r.uid) &&
          r.rider.distanceMeters > furthest) {
        best = r.uid;
        furthest = r.rider.distanceMeters;
      }
    }
    return best;
  }
}
