import '../../../ride/domain/geo_point.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../achievements/achievement.dart';
import '../recap/ride_recap.dart';

/// Everything printed on a shareable ride card, already formatted. The card
/// widget only lays this out; what goes on it is decided here.
class ShareCardData {
  const ShareCardData({
    required this.title,
    required this.dateLabel,
    required this.distance,
    required this.duration,
    required this.averageSpeed,
    required this.topSpeed,
    required this.riders,
    required this.score,
    required this.scoreLabel,
    this.routePoints = const [],
    this.routeSpeedsMps = const [],
    this.routeColorId,
    this.badge,
    this.weatherLabel,
  });

  /// The colour id of the rider whose route is drawn.
  final String? routeColorId;

  final String title;

  /// "7 Nov 2026 · 6:42 PM".
  final String dateLabel;
  final String distance;
  final String duration;
  final String averageSpeed;
  final String topSpeed;

  /// "4 riders" or "Solo".
  final String riders;
  final int score;
  final String scoreLabel;

  /// The route miniature, already thinned to [maxRoutePoints].
  final List<GeoPoint> routePoints;
  final List<double> routeSpeedsMps;

  /// The achievement to feature, if one was earned.
  final Achievement? badge;

  /// "29° · Partly cloudy".
  final String? weatherLabel;

  /// Most route points drawn on the card: plenty for its size.
  static const int maxRoutePoints = 220;
}

/// Builds [ShareCardData]. Pure.
abstract final class ShareCardBuilder {
  /// The card for [recap], showing this rider's own figures where they rode,
  /// and the group's otherwise.
  static ShareCardData fromRecap(RideRecap recap) {
    final group = recap.group;
    final me = recap.me?.rider;
    final rode = me != null && me.distanceMeters > 0;
    final (points, speeds) = _thin(recap.routePoints, recap.routeSpeedsMps);
    final started = recap.startedAt;
    return ShareCardData(
      title: recap.title,
      dateLabel: '${RideFormat.date(started)} · ${RideFormat.time(started)}',
      distance: RideFormat.distance(
        rode ? me.distanceMeters : group.longestDistanceMeters,
      ),
      duration: RideFormat.duration(group.duration),
      averageSpeed: RideFormat.speed(
        rode ? me.averageSpeedMps : group.averageSpeedMps,
      ),
      topSpeed: RideFormat.speed(rode ? me.maxSpeedMps : group.maxSpeedMps),
      riders: group.riderCount <= 1 ? 'Solo' : '${group.riderCount} riders',
      score: recap.score.value,
      scoreLabel: recap.score.label,
      routePoints: points,
      routeSpeedsMps: speeds,
      routeColorId: recap.routeColorId,
      badge: recap.myAchievements.firstOrNull,
      weatherLabel: recap.weather?.summary,
    );
  }

  static (List<GeoPoint>, List<double>) _thin(
    List<GeoPoint> points,
    List<double> speeds,
  ) {
    if (points.length <= ShareCardData.maxRoutePoints) {
      return (points, speeds.length == points.length ? speeds : const []);
    }
    final step = (points.length - 1) / (ShareCardData.maxRoutePoints - 1);
    final indices = [
      for (var i = 0; i < ShareCardData.maxRoutePoints; i++) (i * step).round(),
    ];
    return (
      [for (final i in indices) points[i]],
      speeds.length == points.length
          ? [for (final i in indices) speeds[i]]
          : const <double>[],
    );
  }
}
