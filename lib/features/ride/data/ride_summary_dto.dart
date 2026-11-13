import '../../room/domain/ride_mode.dart';
import '../domain/summary/ride_summary.dart';

/// Realtime Database layout for a finished ride's summary:
///
/// `rideSummaries/{roomCode}` holds the room details, a `group` object, and a
/// `riders` object keyed by uid. It is written once by the host.
abstract final class RideSummaryPaths {
  static String summary(String code) => 'rideSummaries/$code';

  static const String roomName = 'roomName';
  static const String hostUid = 'hostUid';
  static const String mode = 'mode';
  static const String group = 'group';
  static const String riders = 'riders';

  // group fields
  static const String totalDistanceMeters = 'totalDistanceMeters';
  static const String durationMs = 'durationMs';
  static const String averageSpeedMps = 'averageSpeedMps';
  static const String maxSpeedMps = 'maxSpeedMps';
  static const String longestDistanceMeters = 'longestDistanceMeters';
  static const String riderCount = 'riderCount';
  static const String startedAt = 'startedAt';
  static const String endedAt = 'endedAt';

  // rider fields
  static const String displayName = 'displayName';
  static const String colorId = 'colorId';
  static const String isHost = 'isHost';
  static const String distanceMeters = 'distanceMeters';
  static const String movingTimeMs = 'movingTimeMs';
  static const String topSpeedAt = 'topSpeedAt';
  static const String sampleCount = 'sampleCount';
  static const String finished = 'finished';

  const RideSummaryPaths._();
}

/// Maps between [RideSummary] and its stored form.
abstract final class RideSummaryDto {
  /// The stored form of [summary]. Optional values that are unknown are left
  /// out rather than written as null.
  static Map<String, Object?> toValue(RideSummary summary) {
    final group = summary.group;
    return <String, Object?>{
      RideSummaryPaths.roomName: summary.roomName,
      RideSummaryPaths.hostUid: summary.hostUid,
      RideSummaryPaths.mode: summary.mode.wireValue,
      RideSummaryPaths.group: <String, Object?>{
        RideSummaryPaths.totalDistanceMeters: group.totalDistanceMeters,
        RideSummaryPaths.durationMs: group.durationMs,
        RideSummaryPaths.averageSpeedMps: group.averageSpeedMps,
        RideSummaryPaths.maxSpeedMps: group.maxSpeedMps,
        RideSummaryPaths.longestDistanceMeters: group.longestDistanceMeters,
        RideSummaryPaths.riderCount: group.riderCount,
        RideSummaryPaths.startedAt: group.startedAtMs,
        RideSummaryPaths.endedAt: group.endedAtMs,
      },
      RideSummaryPaths.riders: <String, Object?>{
        for (final rider in summary.riders) rider.uid: _riderToValue(rider),
      },
    };
  }

  static Map<String, Object?> _riderToValue(RiderRideSummary rider) {
    return <String, Object?>{
      RideSummaryPaths.displayName: ?rider.displayName,
      RideSummaryPaths.colorId: ?rider.colorId,
      RideSummaryPaths.isHost: rider.isHost,
      RideSummaryPaths.distanceMeters: rider.distanceMeters,
      RideSummaryPaths.movingTimeMs: rider.movingTimeMs,
      RideSummaryPaths.averageSpeedMps: rider.averageSpeedMps,
      RideSummaryPaths.maxSpeedMps: rider.maxSpeedMps,
      RideSummaryPaths.topSpeedAt: ?rider.topSpeedAtMs,
      RideSummaryPaths.sampleCount: rider.sampleCount,
      RideSummaryPaths.startedAt: ?rider.startedAtMs,
      RideSummaryPaths.endedAt: ?rider.endedAtMs,
      RideSummaryPaths.finished: rider.finished,
    };
  }

  /// Builds the summary for room [code] from a stored value, or `null` if it
  /// is absent or incomplete.
  static RideSummary? fromValue(String code, Object? value) {
    if (value is! Map) return null;
    final name = value[RideSummaryPaths.roomName];
    final hostUid = value[RideSummaryPaths.hostUid];
    final mode = RideMode.fromWire(value[RideSummaryPaths.mode] as String?);
    final group = _group(value[RideSummaryPaths.group]);
    final ridersRaw = value[RideSummaryPaths.riders];
    if (name is! String ||
        hostUid is! String ||
        mode == null ||
        group == null ||
        ridersRaw is! Map) {
      return null;
    }

    final riders = <RiderRideSummary>[];
    ridersRaw.forEach((uid, riderValue) {
      final rider = _rider(uid, riderValue);
      if (rider != null) riders.add(rider);
    });
    // Host first, then by distance, so the order is stable.
    riders.sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      return b.distanceMeters.compareTo(a.distanceMeters);
    });

    return RideSummary(
      roomCode: code,
      roomName: name,
      hostUid: hostUid,
      mode: mode,
      group: group,
      riders: riders,
    );
  }

  static GroupRideSummary? _group(Object? value) {
    if (value is! Map) return null;
    final startedAt = value[RideSummaryPaths.startedAt];
    final endedAt = value[RideSummaryPaths.endedAt];
    if (startedAt is! num || endedAt is! num) return null;
    return GroupRideSummary(
      totalDistanceMeters: _double(value[RideSummaryPaths.totalDistanceMeters]),
      durationMs: _double(value[RideSummaryPaths.durationMs]).toInt(),
      averageSpeedMps: _double(value[RideSummaryPaths.averageSpeedMps]),
      maxSpeedMps: _double(value[RideSummaryPaths.maxSpeedMps]),
      longestDistanceMeters: _double(
        value[RideSummaryPaths.longestDistanceMeters],
      ),
      riderCount: _double(value[RideSummaryPaths.riderCount]).toInt(),
      startedAtMs: startedAt.toInt(),
      endedAtMs: endedAt.toInt(),
    );
  }

  static RiderRideSummary? _rider(Object? uid, Object? value) {
    if (uid is! String || value is! Map) return null;
    final name = value[RideSummaryPaths.displayName];
    final colorId = value[RideSummaryPaths.colorId];
    final topSpeedAt = value[RideSummaryPaths.topSpeedAt];
    final startedAt = value[RideSummaryPaths.startedAt];
    final endedAt = value[RideSummaryPaths.endedAt];
    return RiderRideSummary(
      uid: uid,
      displayName: name is String ? name : null,
      colorId: colorId is String ? colorId : null,
      isHost: value[RideSummaryPaths.isHost] == true,
      distanceMeters: _double(value[RideSummaryPaths.distanceMeters]),
      movingTimeMs: _double(value[RideSummaryPaths.movingTimeMs]).toInt(),
      averageSpeedMps: _double(value[RideSummaryPaths.averageSpeedMps]),
      maxSpeedMps: _double(value[RideSummaryPaths.maxSpeedMps]),
      topSpeedAtMs: topSpeedAt is num ? topSpeedAt.toInt() : null,
      sampleCount: _double(value[RideSummaryPaths.sampleCount]).toInt(),
      startedAtMs: startedAt is num ? startedAt.toInt() : null,
      endedAtMs: endedAt is num ? endedAt.toInt() : null,
      finished: value[RideSummaryPaths.finished] == true,
    );
  }

  static double _double(Object? value) => value is num ? value.toDouble() : 0;
}
