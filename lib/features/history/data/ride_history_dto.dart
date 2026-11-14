import '../../ride/domain/geo_point.dart';
import '../../ride/domain/polyline.dart';
import '../../ride/domain/speed_codec.dart';
import '../../room/domain/ride_mode.dart';
import '../domain/recap_highlights.dart';
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

  /// The recap highlights, a child map added once after the ride.
  static const String recap = 'recap';
  static const String recapVersion = 'v';
  static const String recapScore = 'score';
  static const String recapSentence = 'sentence';
  static const String recapAchievements = 'achievements';
  static const String recapWeatherCode = 'weatherCode';
  static const String recapTemperatureC = 'temperatureC';
  static const String recapIsDay = 'isDay';

  const RideHistoryPaths._();
}

/// Maps between [RecapHighlights] and its stored form.
abstract final class RecapHighlightsDto {
  static Map<String, Object?> toValue(RecapHighlights h) => {
    RideHistoryPaths.recapVersion: RecapHighlights.version,
    RideHistoryPaths.recapScore: h.score.clamp(0, 100),
    RideHistoryPaths.recapSentence: h.sentence,
    if (h.achievementIds.isNotEmpty)
      RideHistoryPaths.recapAchievements: h.achievementIds
          .take(RecapHighlights.maxAchievements)
          .join(','),
    if (h.weatherCode != null) RideHistoryPaths.recapWeatherCode: h.weatherCode,
    if (h.temperatureC != null)
      RideHistoryPaths.recapTemperatureC:
          (h.temperatureC! * 10).roundToDouble() / 10,
    if (h.isDay != null) RideHistoryPaths.recapIsDay: h.isDay,
  };

  /// The highlights in [value], or `null` if absent or unreadable.
  static RecapHighlights? fromValue(Object? value) {
    if (value is! Map) return null;
    final score = value[RideHistoryPaths.recapScore];
    final sentence = value[RideHistoryPaths.recapSentence];
    if (score is! num || sentence is! String) return null;
    final achievements = value[RideHistoryPaths.recapAchievements];
    final weatherCode = value[RideHistoryPaths.recapWeatherCode];
    final temperature = value[RideHistoryPaths.recapTemperatureC];
    final isDay = value[RideHistoryPaths.recapIsDay];
    return RecapHighlights(
      score: score.toInt().clamp(0, 100),
      sentence: sentence,
      achievementIds: achievements is String && achievements.isNotEmpty
          ? achievements.split(',')
          : const [],
      weatherCode: weatherCode is num ? weatherCode.toInt() : null,
      temperatureC: temperature is num ? temperature.toDouble() : null,
      isDay: isDay is bool ? isDay : null,
    );
  }
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
    if (entry.highlights != null)
      RideHistoryPaths.recap: RecapHighlightsDto.toValue(entry.highlights!),
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
      highlights: RecapHighlightsDto.fromValue(value[RideHistoryPaths.recap]),
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
