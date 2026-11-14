import '../../../history/domain/recap_highlights.dart';
import '../../../history/domain/ride_details.dart';
import '../../../ride/domain/geo_point.dart';
import '../../../ride/domain/summary/ride_summary.dart';
import '../achievements/achievement.dart';
import '../analysis/ride_insights.dart';
import '../analysis/rider_analytics.dart';
import '../analysis/route_profile.dart';
import '../analysis/speed_profile.dart';
import '../score/ride_score.dart';
import '../weather/weather_snapshot.dart';
import 'recap_narrator.dart';

/// Everything RideSync understands about one finished ride, as seen by one
/// rider: the recap sentence, score, achievements, insights, route analysis,
/// weather and every rider's analytics.
class RideRecap {
  const RideRecap({
    required this.summary,
    required this.myUid,
    required this.score,
    required this.sentence,
    required this.facts,
    required this.achievements,
    required this.insights,
    required this.riders,
    this.route,
    this.weather,
    this.mySpeed,
    this.routePoints = const [],
    this.routeSpeedsMps = const [],
  });

  final RideSummary summary;
  final String? myUid;
  final RideScore score;

  /// The human recap: "A smooth evening ride with 4 riders. …"
  final String sentence;

  /// What [sentence] was written from.
  final RecapFacts facts;

  /// Everything earned on the ride, by anyone, best first.
  final List<Achievement> achievements;

  final List<RideInsight> insights;

  /// Every rider's analytics, in finish order.
  final List<RiderAnalytics> riders;

  final RouteProfile? route;
  final WeatherSnapshot? weather;

  /// This rider's speed profile, if they recorded speeds.
  final SpeedProfile? mySpeed;

  /// The route to draw for this ride: this rider's own, or the furthest
  /// rider's when they have none.
  final List<GeoPoint> routePoints;
  final List<double> routeSpeedsMps;

  String get code => summary.roomCode;
  String get title => summary.roomName;
  DateTime get startedAt =>
      DateTime.fromMillisecondsSinceEpoch(summary.group.startedAtMs);
  GroupRideSummary get group => summary.group;

  /// Achievements this rider earned, plus those shared by the whole ride.
  List<Achievement> get myAchievements => [
    for (final a in achievements)
      if (a.isFor(myUid)) a,
  ];

  /// The best achievement [uid] earned personally, for a badge.
  Achievement? badgeFor(String uid) {
    for (final a in achievements) {
      if (a.holderUid == uid) return a;
    }
    return null;
  }

  /// This rider's analytics, if they were on the ride.
  RiderAnalytics? get me {
    for (final r in riders) {
      if (r.uid == myUid) return r;
    }
    return null;
  }

  /// The compact version kept with the ride's history entry.
  RecapHighlights get highlights => RecapHighlights(
    score: score.value,
    sentence: sentence.length > RecapHighlights.maxSentenceLength
        ? sentence.substring(0, RecapHighlights.maxSentenceLength)
        : sentence,
    achievementIds: [
      for (final a in myAchievements.take(RecapHighlights.maxAchievements))
        a.kind.name,
    ],
    weatherCode: weather?.wmoCode,
    temperatureC: weather?.temperatureC,
    isDay: weather?.isDay,
  );
}

/// What the recap is built from.
class RecapInput {
  const RecapInput({
    required this.details,
    required this.myUid,
    this.weather,
    this.previousRides = const [],
    this.riderNames = const {},
  });

  final RideDetails details;

  /// The name the app shows for each rider, by uid.
  final Map<String, String> riderNames;
  final String? myUid;
  final WeatherSnapshot? weather;

  /// This rider's rides that ended before this one, for personal records.
  final List<PastRide> previousRides;
}
