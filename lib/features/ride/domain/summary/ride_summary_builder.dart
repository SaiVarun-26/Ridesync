import 'dart:math' as math;

import '../../../room/domain/ride_mode.dart';
import '../../../room/domain/room.dart';
import '../../../room/domain/room_member.dart';
import '../stats/ride_stats.dart';
import 'ride_summary.dart';

/// Builds the [RideSummary] from the room and each rider's stats.
///
/// Every rider finishes on their own, so the summary is written again each
/// time one does: a snapshot of the group as it stands, with finished riders'
/// final figures and the others' figures so far. Riders who finished and
/// have left the room since are kept from the [previous] snapshot, so the
/// group is never told without them.
///
/// Pure and deterministic: given the same inputs it always gives the same
/// summary. A member with no stats (never got a GPS fix) appears with zeros,
/// marked as not finished.
abstract final class RideSummaryBuilder {
  static const double _msPerSecond = 1000;

  static RideSummary build({
    required Room room,
    required Map<String, RideStats> stats,
    required int endedAtMs,
    RideSummary? previous,
  }) {
    final riders = <RiderRideSummary>[
      for (final member in room.members) _rider(member, stats[member.uid]),
      // Finished riders who have since left the room.
      for (final earlier in previous?.riders ?? const <RiderRideSummary>[])
        if (room.memberByUid(earlier.uid) == null)
          _carried(earlier, stats[earlier.uid]),
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
    // A solo ride's time leaves its pauses out; a group's runs from the first
    // start to the latest finish, whoever was paused in between.
    final solo = riders.length == 1 ? riders.single : null;
    final duration = solo?.rideTimeMs ?? math.max(0, endedAtMs - startedAt);
    return RideSummary(
      roomCode: room.code,
      roomName: room.name,
      named: !room.namePending,
      hostUid: room.hostUid,
      // A ride only ends after a mode was chosen; free roam is the fallback
      // for a room that somehow has none recorded.
      mode: room.mode ?? RideMode.free,
      group: GroupRideSummary(
        totalDistanceMeters: totalDistance,
        durationMs: duration,
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
      topSpeedPoint: stats?.topSpeedPoint,
      topSpeedDistanceMeters: stats?.topSpeedDistanceMeters,
      sampleCount: stats?.sampleCount ?? 0,
      startedAtMs: stats?.startedAtMs,
      endedAtMs: stats?.endedAtMs,
      finished: stats?.isFinished ?? false,
      pausedMs: stats?.pausedMs ?? 0,
    );
  }

  /// A rider no longer in the room, as last summarised, with their final
  /// stats when those can still be read.
  static RiderRideSummary _carried(RiderRideSummary earlier, RideStats? stats) {
    if (stats == null) return earlier;
    return RiderRideSummary(
      uid: earlier.uid,
      displayName: earlier.displayName,
      colorId: earlier.colorId,
      isHost: earlier.isHost,
      distanceMeters: stats.distanceMeters,
      movingTimeMs: stats.movingTimeMs,
      averageSpeedMps: stats.averageSpeedMps,
      maxSpeedMps: stats.maxSpeedMps,
      topSpeedAtMs: stats.topSpeedAtMs,
      topSpeedPoint: stats.topSpeedPoint,
      topSpeedDistanceMeters: stats.topSpeedDistanceMeters,
      sampleCount: stats.sampleCount,
      startedAtMs: stats.startedAtMs,
      endedAtMs: stats.endedAtMs,
      finished: stats.isFinished,
      pausedMs: stats.pausedMs,
    );
  }
}
