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

  static String _cacheKey(String uid) => 'history_$uid';

  @override
  Future<List<RideHistoryEntry>> cached(String uid) async {
    return RideHistoryDto.pageFromJson(await _cache.read(_cacheKey(uid)));
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
        await _cache.write(_cacheKey(uid), RideHistoryDto.pageToJson(page));
      }
      return Success(RideHistoryPage(entries: page, hasMore: hasMore));
    } on TimeoutException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on FirebaseException catch (e) {
      debugPrint('Loading ride history failed (${e.code}): ${e.message}');
      return Failed(NetworkFailure(cause: e));
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
  Future<Result<void>> record({
    required String uid,
    required String code,
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
      final entry = RideHistoryEntry.fromSummary(summary, uid);
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
