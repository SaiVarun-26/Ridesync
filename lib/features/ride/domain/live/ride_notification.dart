import '../stats/ride_stats.dart';
import 'ride_format.dart';

/// The live content shown in the foreground-service notification while a Free
/// Roam ride is active.
///
/// Built in the main isolate from the ride's stats and pushed to the service,
/// so the notification can show distance, speed and duration without the
/// background task computing anything itself.
class RideNotificationContent {
  const RideNotificationContent({
    required this.distanceText,
    required this.speedText,
    required this.durationText,
  });

  /// Pre-formatted distance, e.g. "4.2 km".
  final String distanceText;

  /// Pre-formatted current speed, e.g. "38 km/h".
  final String speedText;

  /// Pre-formatted elapsed ride time, e.g. "12:04".
  final String durationText;

  /// Notification title line.
  String get title => 'RideSync · Free Roam Active';

  /// Notification body: the three live stats plus a background hint.
  String get body =>
      '$distanceText · $speedText · $durationText\nTracking in background...';

  /// Encodes the content for the background isolate.
  Map<String, Object?> toJson() => <String, Object?>{
    'distance': distanceText,
    'speed': speedText,
    'duration': durationText,
  };

  /// Decodes content sent to the background isolate.
  static RideNotificationContent? fromJson(Object? data) {
    if (data is! Map) return null;
    final distance = data['distance'];
    final speed = data['speed'];
    final duration = data['duration'];
    if (distance is! String || speed is! String || duration is! String) {
      return null;
    }
    return RideNotificationContent(
      distanceText: distance,
      speedText: speed,
      durationText: duration,
    );
  }

  /// Content for the ride as it stands: [stats] gives distance and elapsed
  /// time, [speedMps] is the rider's current speed.
  factory RideNotificationContent.fromRide({
    required RideStats? stats,
    required double speedMps,
    required int nowMs,
  }) {
    return RideNotificationContent(
      distanceText: RideFormat.distance(stats?.distanceMeters ?? 0),
      speedText: RideFormat.speed(speedMps),
      durationText: RideFormat.duration(stats?.elapsed(nowMs) ?? Duration.zero),
    );
  }

  /// The content shown before the first stats arrive.
  static const RideNotificationContent initial = RideNotificationContent(
    distanceText: '0.0 km',
    speedText: '0 km/h',
    durationText: '00:00',
  );
}
