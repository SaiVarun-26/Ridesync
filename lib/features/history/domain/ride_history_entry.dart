import '../../ride/domain/geo_point.dart';
import '../../ride/domain/summary/ride_summary.dart';
import '../../room/domain/ride_mode.dart';
import 'recap_highlights.dart';
import 'ride_details.dart';
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
    this.previewSpeedsMps = const [],
    this.highlights,
    this.colorId,
    this.namePending = false,
    this.position,
  });

  /// Where this rider finished in a group ride (1 for the furthest), by the
  /// distance each rider covered. `null` for solo rides, and for older rides
  /// until it is looked up.
  final int? position;

  /// Whether more than one rider took part.
  bool get isGroup => riderCount > 1;

  /// Whether this entry was saved before the host named the ride, so its
  /// [roomName] is still a placeholder to be replaced by the host's name.
  final bool namePending;

  /// The colour the rider had in this ride (see `RiderPalette`), so the ride
  /// is drawn in it everywhere. `null` for rides saved before it was
  /// recorded, until it is looked up.
  final String? colorId;

  /// The ride's recap figures (score, sentence, achievements, weather), once
  /// they have been worked out; `null` until then.
  final RecapHighlights? highlights;

  /// A thinned copy of the rider's route for the card's miniature; empty for
  /// rides saved without one.
  final List<GeoPoint> routePreview;

  /// The rider's speed at each point of [routePreview], in meters per second.
  /// Empty when speeds were not recorded, and the miniature is then drawn in
  /// one colour.
  final List<double> previewSpeedsMps;

  /// The ride's room code, which also identifies its summary.
  final String code;

  /// The ride's name: the host's name for it, or the rider's own.
  final String roomName;
  final RideMode mode;
  final int startedAtMs;
  final int endedAtMs;
  final int durationMs;
  final double distanceMeters;
  final double averageSpeedMps;
  final double maxSpeedMps;
  final int riderCount;

  RideHistoryEntry _copy({
    String? roomName,
    List<GeoPoint>? routePreview,
    List<double>? previewSpeedsMps,
    RecapHighlights? highlights,
    String? colorId,
    bool? namePending,
    int? position,
  }) {
    return RideHistoryEntry(
      code: code,
      roomName: roomName ?? this.roomName,
      mode: mode,
      startedAtMs: startedAtMs,
      endedAtMs: endedAtMs,
      durationMs: durationMs,
      distanceMeters: distanceMeters,
      averageSpeedMps: averageSpeedMps,
      maxSpeedMps: maxSpeedMps,
      riderCount: riderCount,
      routePreview: routePreview ?? this.routePreview,
      previewSpeedsMps: previewSpeedsMps ?? this.previewSpeedsMps,
      highlights: highlights ?? this.highlights,
      colorId: colorId ?? this.colorId,
      namePending: namePending ?? this.namePending,
      position: position ?? this.position,
    );
  }

  /// This entry with [points] (thinned) as its route miniature, and the
  /// matching [speedsMps] if they were recorded.
  RideHistoryEntry withRoutePreview(
    List<GeoPoint> points, {
    List<double> speedsMps = const [],
  }) {
    return _copy(
      routePreview: RoutePreview.thin(points),
      previewSpeedsMps: speedsMps.length == points.length
          ? RoutePreview.thinValues(speedsMps)
          : const [],
    );
  }

  /// This entry with its recap [highlights].
  RideHistoryEntry withHighlights(RecapHighlights highlights) =>
      _copy(highlights: highlights);

  /// This entry with the rider's [colorId].
  RideHistoryEntry withColorId(String colorId) => _copy(colorId: colorId);

  /// This entry with the rider's finishing [position].
  RideHistoryEntry withPosition(int position) => _copy(position: position);

  /// This entry under [name], which is no longer waiting for the host's.
  RideHistoryEntry withName(String name) =>
      _copy(roomName: name, namePending: false);

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
      colorId: rider.colorId,
      namePending: !summary.named,
      position: positionIn(summary, riderUid),
    );
  }

  /// Where [riderUid] finished in [summary]: their place by distance covered,
  /// or `null` for a solo ride.
  static int? positionIn(RideSummary summary, String riderUid) {
    if (summary.riders.length < 2) return null;
    final ranked = RideRankings.rank(summary.riders, RankMetric.distance);
    final index = ranked.indexWhere((r) => r.uid == riderUid);
    return index < 0 ? null : index + 1;
  }
}

/// One page of history, newest first.
class RideHistoryPage {
  const RideHistoryPage({required this.entries, required this.hasMore});

  final List<RideHistoryEntry> entries;

  /// Whether older rides exist beyond this page.
  final bool hasMore;
}
