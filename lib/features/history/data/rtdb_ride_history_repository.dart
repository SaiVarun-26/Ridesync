import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../ride/data/ride_stats_dto.dart';
import '../../ride/data/ride_summary_dto.dart';
import '../../ride/domain/geo_point.dart';
import '../../ride/domain/polyline.dart';
import '../../ride/domain/speed_codec.dart';
import '../domain/recap_highlights.dart';
import '../domain/ride_history_entry.dart';
import '../domain/ride_history_repository.dart';
import 'json_cache.dart';
import 'ride_history_dto.dart';

/// [RideHistoryRepository] on the Realtime Database, with the newest page kept
/// on the device.
///
/// Pages are fetched once with a query ordered by `endedAt`, so nothing is
/// listened to and nothing downloads more than one page.
class RtdbRideHistoryRepository implements RideHistoryRepository {
  RtdbRideHistoryRepository({
    required FirebaseDatabase database,
    required JsonCache cache,
    this.timeout = const Duration(seconds: 10),
  }) : _database = database,
       _cache = cache;

  final FirebaseDatabase _database;
  final JsonCache _cache;

  /// How long to wait for the database before treating the network as down.
  final Duration timeout;

  /// Where the newest page of [uid]'s history is kept on the device.
  static String cacheKey(String uid) => 'history_$uid';

  @override
  Future<List<RideHistoryEntry>> cached(String uid) async {
    return RideHistoryDto.pageFromJson(await _cache.read(cacheKey(uid)));
  }

  @override
  Future<Result<RideHistoryPage>> loadPage({
    required String uid,
    RideHistoryEntry? after,
    int limit = 20,
  }) async {
    try {
      // One extra row tells us whether older rides exist. When continuing,
      // the cursor's own row comes back too (the query is inclusive), so ask
      // for one more.
      final fetch = limit + 1 + (after == null ? 0 : 1);
      Query query = _database
          .ref(RideHistoryPaths.all(uid))
          .orderByChild(RideHistoryPaths.endedAt);
      if (after != null) {
        query = query.endAt(after.endedAtMs, key: after.code);
      }
      final snapshot = await query.limitToLast(fetch).get().timeout(timeout);

      final entries = <RideHistoryEntry>[];
      for (final child in snapshot.children) {
        final key = child.key;
        if (key == null || key == after?.code) continue;
        final entry = RideHistoryDto.fromValue(key, child.value);
        if (entry != null) entries.add(entry);
      }
      // Newest first; the code breaks ties so the order is stable.
      entries.sort((a, b) {
        final byTime = b.endedAtMs.compareTo(a.endedAtMs);
        return byTime != 0 ? byTime : b.code.compareTo(a.code);
      });

      final hasMore = entries.length > limit;
      final page = hasMore ? entries.sublist(0, limit) : entries;
      if (after == null) {
        await _cache.write(cacheKey(uid), RideHistoryDto.pageToJson(page));
      }
      return Success(RideHistoryPage(entries: page, hasMore: hasMore));
    } on TimeoutException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on FirebaseException catch (e) {
      debugPrint('Loading ride history failed (${e.code}): ${e.message}');
      return Failed(NetworkFailure(cause: e));
    }
  }

  @override
  Future<List<RideHistoryEntry>> personalBests({
    required String uid,
    int count = 3,
  }) async {
    // Two tiny indexed queries: the top few by distance and by top speed.
    Future<List<RideHistoryEntry>> top(String field) async {
      final snapshot = await _database
          .ref(RideHistoryPaths.all(uid))
          .orderByChild(field)
          .limitToLast(count)
          .get()
          .timeout(timeout);
      return [
        for (final child in snapshot.children)
          if (child.key != null)
            ?RideHistoryDto.fromValue(child.key!, child.value),
      ];
    }

    try {
      final results = await Future.wait([
        top(RideHistoryPaths.distanceMeters),
        top(RideHistoryPaths.maxSpeedMps),
      ]);
      final byCode = <String, RideHistoryEntry>{
        for (final list in results)
          for (final entry in list) entry.code: entry,
      };
      return byCode.values.toList();
    } on Object catch (e) {
      debugPrint('Loading personal bests skipped: $e');
      return const [];
    }
  }

  /// The rider's own route, or none if it cannot be read. The miniature is
  /// a nicety, so a missing route never stops the ride being recorded.
  Future<({List<GeoPoint> points, List<double> speeds})> _ownRoute(
    String uid,
    String code,
  ) async {
    try {
      final snapshot = await _database
          .ref('${RideStatsPaths.routes(code)}/$uid')
          .get()
          .timeout(timeout);
      final value = snapshot.value;
      if (value is! Map) {
        return (points: const <GeoPoint>[], speeds: const <double>[]);
      }
      final polyline = value[RideStatsPaths.polyline];
      final speeds = value[RideStatsPaths.speeds];
      return (
        points: polyline is String
            ? decodePolyline(polyline)
            : const <GeoPoint>[],
        speeds: speeds is String ? SpeedCodec.decode(speeds) : const <double>[],
      );
    } on Object catch (e) {
      debugPrint('Reading the route for the preview failed: $e');
      return (points: const <GeoPoint>[], speeds: const <double>[]);
    }
  }

  @override
  Future<RideHistoryEntry?> generatePreview({
    required String uid,
    required RideHistoryEntry entry,
  }) async {
    final route = await _ownRoute(uid, entry.code);
    if (route.points.length < 2) return null;
    final withPreview = entry.withRoutePreview(
      route.points,
      speedsMps: route.speeds,
    );
    try {
      // Saved onto the ride's history entry so every device has it from now
      // on. The rules only allow adding a preview, never changing one.
      await _database
          .ref(RideHistoryPaths.entry(uid, entry.code))
          .update(<String, Object?>{
            RideHistoryPaths.preview: encodePolyline(withPreview.routePreview),
            if (withPreview.previewSpeedsMps.isNotEmpty)
              RideHistoryPaths.previewSpeeds: SpeedCodec.encode(
                withPreview.previewSpeedsMps,
              ),
          })
          .timeout(timeout);
    } on Object catch (e) {
      // Not saved is fine: the preview is still shown for this session.
      debugPrint('Saving the generated preview failed: $e');
    }
    return withPreview;
  }

  @override
  Future<RideHistoryEntry?> resolveMissing({
    required String uid,
    required RideHistoryEntry entry,
  }) async {
    try {
      // The colour the rider claimed, and every rider's distance (for their
      // finishing place), are part of the ride's summary: one small read.
      final snapshot = await _database
          .ref(
            '${RideSummaryPaths.summary(entry.code)}/${RideSummaryPaths.riders}',
          )
          .get()
          .timeout(timeout);
      final riders = snapshot.value;
      if (riders is! Map) return null;
      final mine = riders[uid];
      final colorId = mine is Map ? mine[RideSummaryPaths.colorId] : null;
      int? position;
      if (riders.length >= 2) {
        final distances = <String, double>{
          for (final MapEntry(:key, :value) in riders.entries)
            if (key is String && value is Map)
              key: switch (value[RideSummaryPaths.distanceMeters]) {
                final num d => d.toDouble(),
                _ => 0,
              },
        };
        final ahead = distances.values
            .where((d) => d > (distances[uid] ?? 0))
            .length;
        if (distances.containsKey(uid)) position = ahead + 1;
      }

      var resolved = entry;
      final updates = <String, Object?>{};
      if (entry.colorId == null && colorId is String && colorId.isNotEmpty) {
        resolved = resolved.withColorId(colorId);
        updates[RideHistoryPaths.colorId] = colorId;
      }
      if (entry.position == null && position != null) {
        resolved = resolved.withPosition(position);
        updates[RideHistoryPaths.position] = position;
      }
      if (updates.isEmpty) return null;
      // Saved onto the history entry so every device has them from now on.
      // The rules only allow adding them, never changing them. Written one by
      // one, so a value already present never blocks the other.
      for (final MapEntry(:key, :value) in updates.entries) {
        try {
          await _database
              .ref('${RideHistoryPaths.entry(uid, entry.code)}/$key')
              .set(value)
              .timeout(timeout);
        } on Object catch (e) {
          // Not saved is fine: it is still shown for this session.
          debugPrint('Saving the ride $key failed: $e');
        }
      }
      return resolved;
    } on Object catch (e) {
      debugPrint('Looking up the ride colour and place failed: $e');
      return null;
    }
  }

  @override
  Future<bool> saveHighlights({
    required String uid,
    required String code,
    required RecapHighlights highlights,
  }) async {
    try {
      // The rules accept this child only once, and only on an entry that
      // already exists, so it can never create a half-made history entry.
      await _database
          .ref('${RideHistoryPaths.entry(uid, code)}/${RideHistoryPaths.recap}')
          .set(RecapHighlightsDto.toValue(highlights))
          .timeout(timeout);
      return true;
    } on Object catch (e) {
      debugPrint('Saving recap highlights skipped: $e');
      return false;
    }
  }

  @override
  Future<Result<RideHistoryEntry?>> entry({
    required String uid,
    required String code,
  }) async {
    try {
      final snapshot = await _database
          .ref(RideHistoryPaths.entry(uid, code))
          .get()
          .timeout(timeout);
      return Success(RideHistoryDto.fromValue(code, snapshot.value));
    } on TimeoutException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on FirebaseException catch (e) {
      return Failed(NetworkFailure(cause: e));
    }
  }

  @override
  Future<Result<void>> delete({
    required String uid,
    required String code,
  }) async {
    try {
      // Read while the entry still grants access to the ride's records.
      final summary = RideSummaryDto.fromValue(
        code,
        (await _database
                .ref(RideSummaryPaths.summary(code))
                .get()
                .timeout(timeout))
            .value,
      );
      final solo =
          summary != null &&
          summary.riders.length == 1 &&
          summary.riders.single.uid == uid;
      Future<void> remove(String path) =>
          _database.ref(path).remove().timeout(timeout);
      if (solo) {
        // Nobody else shares a solo ride: everything of it goes. The summary
        // last, since the rules check it to allow the rest.
        await remove('${RideStatsPaths.routes(code)}/$uid');
        await remove('${RideStatsPaths.stats(code)}/$uid');
        await remove('rideWeather/$code');
        await remove('rooms/$code');
        await remove(RideSummaryPaths.summary(code));
      }
      await remove(RideHistoryPaths.entry(uid, code));
      await _forgetOnDevice(uid: uid, code: code);
      return const Success(null);
    } on TimeoutException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on FirebaseException catch (e) {
      debugPrint('Deleting the ride failed (${e.code}): ${e.message}');
      return Failed(NetworkFailure(cause: e));
    }
  }

  /// Drops ride [code] from the device's saved history page and its saved
  /// details and weather.
  Future<void> _forgetOnDevice({
    required String uid,
    required String code,
  }) async {
    final key = cacheKey(uid);
    final page = await _cache.read(key);
    final entries = page?['entries'];
    if (page != null && entries is List) {
      entries.removeWhere((e) => e is Map && e['code'] == code);
      await _cache.write(key, page);
    }
    await _cache.remove('details_$code');
    await _cache.remove('weather_$code');
  }

  @override
  Future<Result<void>> record({
    required String uid,
    required String code,
    String? name,
  }) async {
    try {
      final entryRef = _database.ref(RideHistoryPaths.entry(uid, code));
      if ((await entryRef.get().timeout(timeout)).exists) {
        return const Success(null);
      }

      final summarySnapshot = await _database
          .ref(RideSummaryPaths.summary(code))
          .get()
          .timeout(timeout);
      final summary = RideSummaryDto.fromValue(code, summarySnapshot.value);
      if (summary == null) {
        return const Failed(
          NotFoundFailure(message: 'Ride results not found.'),
        );
      }
      final entry = RideHistoryEntry.fromSummary(summary, uid, name: name);
      // Not part of this ride (for example joined after it ended).
      if (entry == null) return const Success(null);

      final route = await _ownRoute(uid, code);
      final withPreview = entry.withRoutePreview(
        route.points,
        speedsMps: route.speeds,
      );
      await entryRef.set(RideHistoryDto.toValue(withPreview)).timeout(timeout);
      return const Success(null);
    } on TimeoutException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on FirebaseException catch (e) {
      debugPrint('Recording ride history failed (${e.code}): ${e.message}');
      return Failed(NetworkFailure(cause: e));
    }
  }
}
