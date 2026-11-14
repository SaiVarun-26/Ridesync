import '../../../ride/domain/summary/ride_summary.dart';
import '../analysis/rider_analytics.dart';
import '../analysis/route_profile.dart';
import '../weather/weather_snapshot.dart';

/// Every kind of achievement there is. The name is what is stored, so
/// existing names must never change; new kinds can be added freely, and a
/// stored name this version does not know is simply skipped.
enum AchievementKind {
  longestRide,
  topSpeedRecord,
  bestFinish,
  distanceLeader,
  groupLeader,
  fastestSprint,
  longestContinuous,
  smoothestRide,
  consistentPace,
  nightRide;

  static AchievementKind? fromName(String name) =>
      AchievementKind.values.asNameMap()[name];
}

/// Something worth celebrating about a ride.
class Achievement {
  const Achievement({
    required this.kind,
    required this.title,
    required this.detail,
    required this.priority,
    this.holderUid,
  });

  final AchievementKind kind;
  final String title;

  /// One line saying what earned it: "24.3 km, your longest yet".
  final String detail;

  /// Higher shows first.
  final int priority;

  /// The rider who earned it; `null` when it belongs to the whole ride.
  final String? holderUid;

  /// Whether [uid] earned it, or it is shared by everyone on the ride.
  bool isFor(String? uid) => holderUid == null || holderUid == uid;
}

/// A ride this rider finished before, as far as records go.
class PastRide {
  const PastRide({
    required this.code,
    required this.endedAtMs,
    required this.distanceMeters,
    required this.maxSpeedMps,
  });

  final String code;
  final int endedAtMs;
  final double distanceMeters;
  final double maxSpeedMps;
}

/// Everything an [AchievementRule] can look at.
class AchievementContext {
  const AchievementContext({
    required this.summary,
    required this.riders,
    required this.myUid,
    required this.previousRides,
    this.route,
    this.weather,
  });

  final RideSummary summary;

  /// Every rider's analytics, in finish order.
  final List<RiderAnalytics> riders;

  /// Who is looking at the ride, for personal records.
  final String? myUid;

  /// This rider's rides that ended before this one.
  final List<PastRide> previousRides;

  final RouteProfile? route;
  final WeatherSnapshot? weather;

  /// Riders who actually covered ground.
  List<RiderAnalytics> get riding => [
    for (final r in riders)
      if (r.rode) r,
  ];

  RiderAnalytics? get me {
    for (final r in riders) {
      if (r.uid == myUid) return r;
    }
    return null;
  }

  bool get isGroup => riding.length >= 2;
}

/// One way of earning achievements. Rules are independent: add a new one to
/// [AchievementEngine.defaultRules] and it takes part in every ride.
abstract interface class AchievementRule {
  Iterable<Achievement> evaluate(AchievementContext context);
}

/// Runs every rule over a ride and returns what was earned, best first.
class AchievementEngine {
  const AchievementEngine(this.rules);

  final List<AchievementRule> rules;

  List<Achievement> evaluate(AchievementContext context) {
    final earned = [for (final rule in rules) ...rule.evaluate(context)]
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return earned;
  }
}
