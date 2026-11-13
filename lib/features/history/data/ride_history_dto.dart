import '../../ride/domain/geo_point.dart';
import '../../ride/domain/polyline.dart';
import '../../ride/domain/speed_codec.dart';
import '../../room/domain/ride_mode.dart';
import '../domain/ride_history_entry.dart';

/// Realtime Database layout for a rider's ride history:
///
/// `userRides/{uid}/{roomCode}` holds the numbers a history card needs. It is
/// written once by the rider when they reach the results, and read one page at
/// a time ordered by `endedAt`.
abstract final class RideHistoryPaths {
  static String all(String uid) => 'userRides/$uid';
  static String entry(String uid, String code) => 'userRides/$uid/$code';

  static const String roomName = 'roomName';
  static const String mode = 'mode';
  static const String startedAt = 'startedAt';
  static const String endedAt = 'endedAt';
  static const String durationMs = 'durationMs';
  static const String distanceMeters = 'distanceMeters';
  static const String averageSpeedMps = 'averageSpeedMps';
  static const String maxSpeedMps = 'maxSpeedMps';
  static const String riderCount = 'riderCount';
  static const String preview = 'preview';
  static const String previewSpeeds = 'previewSpeeds';

  const RideHistoryPaths._();
}

/// Maps between [RideHistoryEntry] and its stored form.
abstract final class RideHistoryDto {
  static Map<String, Object?> toValue(RideHistoryEntry entry) => {
    RideHistoryPaths.roomName: entry.roomName,
    RideHistoryPaths.mode: entry.mode.wireValue,
    RideHistoryPaths.startedAt: entry.startedAtMs,
    RideHistoryPaths.endedAt: entry.endedAtMs,
    RideHistoryPaths.durationMs: entry.durationMs,
    RideHistoryPaths.distanceMeters: entry.distanceMeters,
    RideHistoryPaths.averageSpeedMps: entry.averageSpeedMps,
    RideHistoryPaths.maxSpeedMps: entry.maxSpeedMps,
    RideHistoryPaths.riderCount: entry.riderCount,
    if (entry.routePreview.isNotEmpty)
      RideHistoryPaths.preview: encodePolyline(entry.routePreview),
    if (entry.previewSpeedsMps.isNotEmpty)
      RideHistoryPaths.previewSpeeds: SpeedCodec.encode(entry.previewSpeedsMps),
  };

  /// The entry for ride [code], or `null` if [value] is absent or incomplete.
  static RideHistoryEntry? fromValue(String code, Object? value) {
    if (value is! Map) return null;
    final name = value[RideHistoryPaths.roomName];
    final mode = RideMode.fromWire(value[RideHistoryPaths.mode] as String?);
    final endedAt = value[RideHistoryPaths.endedAt];
    if (name is! String || mode == null || endedAt is! num) return null;
    final startedAt = value[RideHistoryPaths.startedAt];
    final preview = value[RideHistoryPaths.preview];
    final previewSpeeds = value[RideHistoryPaths.previewSpeeds];
    final previewPoints = preview is String
        ? decodePolyline(preview)
        : const <GeoPoint>[];
    final speeds = previewSpeeds is String
        ? SpeedCodec.decode(previewSpeeds)
        : const <double>[];
    return RideHistoryEntry(
      code: code,
      roomName: name,
      mode: mode,
      startedAtMs: startedAt is num ? startedAt.toInt() : endedAt.toInt(),
      endedAtMs: endedAt.toInt(),
      durationMs: _number(value[RideHistoryPaths.durationMs]).toInt(),
      distanceMeters: _number(value[RideHistoryPaths.distanceMeters]),
      averageSpeedMps: _number(value[RideHistoryPaths.averageSpeedMps]),
      maxSpeedMps: _number(value[RideHistoryPaths.maxSpeedMps]),
      riderCount: _number(value[RideHistoryPaths.riderCount]).toInt(),
      routePreview: previewPoints,
      previewSpeedsMps: speeds.length == previewPoints.length
          ? speeds
          : const [],
    );
  }

  /// The on-device form of a page: each entry's stored form plus its code.
  static Map<String, Object?> pageToJson(List<RideHistoryEntry> entries) => {
    'entries': [
      for (final entry in entries) {'code': entry.code, ...toValue(entry)},
    ],
  };

  static List<RideHistoryEntry> pageFromJson(Map<String, Object?>? json) {
    final raw = json?['entries'];
    if (raw is! List) return const [];
    final entries = <RideHistoryEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final code = item['code'];
      if (code is! String) continue;
      final entry = fromValue(code, item);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  static double _number(Object? value) => value is num ? value.toDouble() : 0;
}
