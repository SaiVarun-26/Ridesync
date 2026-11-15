import '../geo_point.dart';
import '../live/ride_format.dart';

/// The guided part of a status report.
class RouteStatus {
  const RouteStatus({
    required this.destinationName,
    required this.remainingMeters,
    required this.fraction,
    this.remainingTime,
    this.hasArrived = false,
  });

  final String destinationName;
  final double remainingMeters;
  final double fraction;
  final Duration? remainingTime;
  final bool hasArrived;
}

/// Builds the plain-text "where I am" message a rider can share with anyone
/// outside the ride (a friend, family), through any app.
abstract final class RideStatusReport {
  /// A short, readable status. Coordinates go out as an OpenStreetMap link
  /// that opens in any browser or map app.
  static String compose({
    required String rideName,
    required DateTime now,
    GeoPoint? at,
    double? speedMps,
    double distanceMeters = 0,
    Duration elapsed = Duration.zero,
    RouteStatus? route,
  }) {
    final lines = <String>[
      'RideSync live status · $rideName',
      if (at != null) 'I am here: ${mapLink(at)}',
      [
        if (speedMps != null) RideFormat.speed(speedMps),
        '${RideFormat.distance(distanceMeters)} ridden',
        'riding for ${RideFormat.eta(elapsed).replaceFirst('Under 1 min', 'under a minute')}',
      ].join(' · '),
      if (route != null)
        route.hasArrived
            ? 'Arrived at ${route.destinationName}.'
            : 'Heading to ${route.destinationName}: '
                  '${RideFormat.distance(route.remainingMeters)} to go '
                  '(${(route.fraction * 100).round()}% done)'
                  '${route.remainingTime == null ? '' : ', about ${RideFormat.eta(route.remainingTime!)} left'}.',
      'Sent at ${RideFormat.time(now)}',
    ];
    return lines.join('\n');
  }

  /// An OpenStreetMap link with a pin at [at].
  static String mapLink(GeoPoint at) {
    final lat = at.latitude.toStringAsFixed(5);
    final lng = at.longitude.toStringAsFixed(5);
    return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng';
  }
}
