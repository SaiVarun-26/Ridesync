import '../../ride/domain/geo_point.dart';
import '../../ride/domain/summary/ride_summary.dart';
import '../../room/domain/ride_mode.dart';
import 'route_preview.dart';

/// One finished ride in a rider's history: the numbers a history card shows.
///
/// Distance and speeds are the rider's own; duration and rider count are the
/// group's. The full results stay in the ride's summary and are only loaded
/// when the rider opens the ride.
class RideHistoryEntry {
  const RideHistoryEntry({
    required this.code,
    required this.roomName,
    required this.mode,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.durationMs,
    required this.distanceMeters,
    required this.averageSpeedMps,
    required this.maxSpeedMps,
    required this.riderCount,
    this.routePreview = const [],
  });

  /// A thinned copy of the rider's route for the card's miniature; empty for
  /// rides saved without one.
  final List<GeoPoint> routePreview;

  /// The ride's room code, which also identifies its summary.
  final String code;
  final String roomName;
  final RideMode mode;
  final int startedAtMs;
  final int endedAtMs;
  final int durationMs;
  final double distanceMeters;
  final double averageSpeedMps;
  final double maxSpeedMps;
  final int riderCount;

  /// This entry with [points] (thinned) as its route miniature.
  RideHistoryEntry withRoutePreview(List<GeoPoint> points) {
    return RideHistoryEntry(
      code: code,
      roomName: roomName,
      mode: mode,
      startedAtMs: startedAtMs,
      endedAtMs: endedAtMs,
      durationMs: durationMs,
      distanceMeters: distanceMeters,
      averageSpeedMps: averageSpeedMps,
      maxSpeedMps: maxSpeedMps,
      riderCount: riderCount,
      routePreview: RoutePreview.thin(points),
    );
  }

  DateTime get endedAt => DateTime.fromMillisecondsSinceEpoch(endedAtMs);

  Duration get duration => Duration(milliseconds: durationMs);

  /// The history entry for [riderUid] in [summary], or `null` when that rider
  /// was not part of the ride.
  static RideHistoryEntry? fromSummary(RideSummary summary, String riderUid) {
    RiderRideSummary? rider;
    for (final candidate in summary.riders) {
      if (candidate.uid == riderUid) rider = candidate;
    }
    if (rider == null) return null;
    final group = summary.group;
    return RideHistoryEntry(
      code: summary.roomCode,
      roomName: summary.roomName,
      mode: summary.mode,
      startedAtMs: group.startedAtMs,
      endedAtMs: group.endedAtMs,
      durationMs: group.durationMs,
      distanceMeters: rider.distanceMeters,
      averageSpeedMps: rider.averageSpeedMps,
      maxSpeedMps: rider.maxSpeedMps,
      riderCount: group.riderCount,
    );
  }
}

/// One page of history, newest first.
class RideHistoryPage {
  const RideHistoryPage({required this.entries, required this.hasMore});

  final List<RideHistoryEntry> entries;

  /// Whether older rides exist beyond this page.
  final bool hasMore;
}
