import '../../../room/domain/ride_mode.dart';

/// The whole group's figures for a finished ride.
class GroupRideSummary {
  const GroupRideSummary({
    required this.totalDistanceMeters,
    required this.durationMs,
    required this.averageSpeedMps,
    required this.maxSpeedMps,
    required this.longestDistanceMeters,
    required this.riderCount,
    required this.startedAtMs,
    required this.endedAtMs,
  });

  /// Distance ridden by all riders added together.
  final double totalDistanceMeters;

  /// From the first rider starting to the host ending the ride.
  final int durationMs;

  /// Group average speed while moving: total distance over total moving time.
  final double averageSpeedMps;

  /// Highest speed reached by any rider.
  final double maxSpeedMps;

  /// The furthest any single rider travelled.
  final double longestDistanceMeters;

  final int riderCount;

  /// Epoch millis of the earliest rider start.
  final int startedAtMs;

  /// Epoch millis when the host ended the ride.
  final int endedAtMs;

  /// The ride's length as a [Duration].
  Duration get duration => Duration(milliseconds: durationMs);
}

/// One rider's figures for a finished ride, frozen when the ride ended.
///
/// Copied into the summary (rather than read later from the live stats) so the
/// results survive riders leaving the room.
class RiderRideSummary {
  const RiderRideSummary({
    required this.uid,
    required this.displayName,
    required this.colorId,
    required this.isHost,
    required this.distanceMeters,
    required this.movingTimeMs,
    required this.averageSpeedMps,
    required this.maxSpeedMps,
    required this.topSpeedAtMs,
    required this.sampleCount,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.finished,
  });

  final String uid;
  final String? displayName;

  /// The rider's claimed color id (see `RiderPalette`).
  final String? colorId;
  final bool isHost;

  final double distanceMeters;
  final int movingTimeMs;
  final double averageSpeedMps;
  final double maxSpeedMps;

  /// When [maxSpeedMps] was reached (epoch millis), if it was.
  final int? topSpeedAtMs;
  final int sampleCount;

  /// When this rider's ride began, or `null` if they never got a GPS fix.
  final int? startedAtMs;

  /// When this rider's stats were frozen, or `null` if they did not respond
  /// before the host closed the ride (their last saved stats are used).
  final int? endedAtMs;

  /// Whether the rider confirmed their final stats in time.
  final bool finished;

  /// Moving time as a [Duration].
  Duration get movingTime => Duration(milliseconds: movingTimeMs);
}

/// Everything the results screens need about a finished ride.
class RideSummary {
  const RideSummary({
    required this.roomCode,
    required this.roomName,
    required this.hostUid,
    required this.mode,
    required this.group,
    required this.riders,
  });

  final String roomCode;
  final String roomName;
  final String hostUid;
  final RideMode mode;
  final GroupRideSummary group;

  /// Every rider in the room at the end, host first.
  final List<RiderRideSummary> riders;
}
