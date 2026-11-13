import 'dart:math' as math;

import '../../../room/domain/ride_mode.dart';
import '../../../room/domain/room.dart';
import '../../../room/domain/room_member.dart';
import '../stats/ride_stats.dart';
import 'ride_summary.dart';

/// Builds the [RideSummary] from the room and each rider's final stats.
///
/// Pure and deterministic: given the same inputs it always gives the same
/// summary. Every member of the room appears in the summary. A member with no
/// stats (never got a GPS fix, or did not respond in time) appears with zeros
/// or with their last saved figures, marked as not finished.
abstract final class RideSummaryBuilder {
  static const double _msPerSecond = 1000;

  static RideSummary build({
    required Room room,
    required Map<String, RideStats> stats,
    required int endedAtMs,
  }) {
    final riders = [
      for (final member in room.members) _rider(member, stats[member.uid]),
    ];

    var totalDistance = 0.0;
    var totalMovingMs = 0;
    var maxSpeed = 0.0;
    var longest = 0.0;
    int? earliestStart;
    for (final rider in riders) {
      totalDistance += rider.distanceMeters;
      totalMovingMs += rider.movingTimeMs;
      maxSpeed = math.max(maxSpeed, rider.maxSpeedMps);
      longest = math.max(longest, rider.distanceMeters);
      final started = rider.startedAtMs;
      if (started != null) {
        earliestStart = earliestStart == null
            ? started
            : math.min(earliestStart, started);
      }
    }

    final startedAt = earliestStart ?? endedAtMs;
    return RideSummary(
      roomCode: room.code,
      roomName: room.name,
      hostUid: room.hostUid,
      // A ride only ends after a mode was chosen; free roam is the fallback
      // for a room that somehow has none recorded.
      mode: room.mode ?? RideMode.free,
      group: GroupRideSummary(
        totalDistanceMeters: totalDistance,
        durationMs: math.max(0, endedAtMs - startedAt),
        averageSpeedMps: totalMovingMs <= 0
            ? 0
            : totalDistance / (totalMovingMs / _msPerSecond),
        maxSpeedMps: maxSpeed,
        longestDistanceMeters: longest,
        riderCount: riders.length,
        startedAtMs: startedAt,
        endedAtMs: endedAtMs,
      ),
      riders: riders,
    );
  }

  static RiderRideSummary _rider(RoomMember member, RideStats? stats) {
    return RiderRideSummary(
      uid: member.uid,
      displayName: member.displayName,
      colorId: member.colorId,
      isHost: member.isHost,
      distanceMeters: stats?.distanceMeters ?? 0,
      movingTimeMs: stats?.movingTimeMs ?? 0,
      averageSpeedMps: stats?.averageSpeedMps ?? 0,
      maxSpeedMps: stats?.maxSpeedMps ?? 0,
      topSpeedAtMs: stats?.topSpeedAtMs,
      sampleCount: stats?.sampleCount ?? 0,
      startedAtMs: stats?.startedAtMs,
      endedAtMs: stats?.endedAtMs,
      finished: stats?.isFinished ?? false,
    );
  }
}
