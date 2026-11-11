import '../../ride/domain/geo_point.dart';
import '../../ride/domain/summary/ride_summary.dart';
import 'speed_scale.dart';

/// One rider's recorded route: where they went and, when it was recorded, how
/// fast at each point.
class RiderRoute {
  RiderRoute({required this.points, List<double> speedsMps = const []})
    : speedsMps = speedsMps.length == points.length
          ? speedsMps
          : const <double>[];

  final List<GeoPoint> points;

  /// Speed in meters per second at each point, in step with [points]. Empty
  /// for rides saved before speeds were recorded.
  final List<double> speedsMps;

  bool get hasSpeeds => speedsMps.isNotEmpty;

  /// [speedsMps] with GPS noise evened out, for colouring the route.
  late final List<double> smoothedSpeedsMps = SpeedScale.smooth(
    speedsMps,
    radius: 2,
  );
}

/// Everything the ride details screen shows about one finished ride.
class RideDetails {
  const RideDetails({
    required this.summary,
    required this.routes,
    this.fromCache = false,
  });

  final RideSummary summary;

  /// Each rider's recorded route, by uid. Riders without a route are absent.
  final Map<String, RiderRoute> routes;

  /// Whether this came from the device because the network was unavailable.
  final bool fromCache;
}

/// What riders can be ranked by.
enum RankMetric {
  distance('Distance'),
  topSpeed('Top speed'),
  averageSpeed('Avg speed');

  const RankMetric(this.label);

  final String label;

  /// The figure [rider] is ranked on.
  double valueOf(RiderRideSummary rider) => switch (this) {
    RankMetric.distance => rider.distanceMeters,
    RankMetric.topSpeed => rider.maxSpeedMps,
    RankMetric.averageSpeed => rider.averageSpeedMps,
  };
}

/// Orders the riders of a finished ride. Pure, so the ordering is easy to
/// check.
abstract final class RideRankings {
  /// Riders from best to worst on [metric]. Ties go to the rider who rode
  /// further, then to whoever started first in the list, so the order is
  /// stable.
  static List<RiderRideSummary> rank(
    List<RiderRideSummary> riders,
    RankMetric metric,
  ) {
    final indexed = riders.indexed.toList();
    indexed.sort((a, b) {
      final byMetric = metric.valueOf(b.$2).compareTo(metric.valueOf(a.$2));
      if (byMetric != 0) return byMetric;
      final byDistance = b.$2.distanceMeters.compareTo(a.$2.distanceMeters);
      return byDistance != 0 ? byDistance : a.$1.compareTo(b.$1);
    });
    return [for (final item in indexed) item.$2];
  }

  /// Riders in the order they finished: those who confirmed their final stats
  /// first, earliest first. Riders who did not confirm in time come last,
  /// furthest first.
  static List<RiderRideSummary> finishOrder(List<RiderRideSummary> riders) {
    final indexed = riders.indexed.toList();
    bool confirmed(RiderRideSummary r) => r.finished && r.endedAtMs != null;
    indexed.sort((a, b) {
      final aDone = confirmed(a.$2);
      final bDone = confirmed(b.$2);
      if (aDone != bDone) return aDone ? -1 : 1;
      if (aDone) {
        final byTime = a.$2.endedAtMs!.compareTo(b.$2.endedAtMs!);
        if (byTime != 0) return byTime;
      } else {
        final byDistance = b.$2.distanceMeters.compareTo(a.$2.distanceMeters);
        if (byDistance != 0) return byDistance;
      }
      return a.$1.compareTo(b.$1);
    });
    return [for (final item in indexed) item.$2];
  }
}
