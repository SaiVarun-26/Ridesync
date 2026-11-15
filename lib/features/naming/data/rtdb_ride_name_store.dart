import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../history/data/json_cache.dart';
import '../../history/data/ride_history_dto.dart';
import '../../history/data/rtdb_ride_details_repository.dart';
import '../../history/data/rtdb_ride_history_repository.dart';
import '../../ride/data/ride_summary_dto.dart';
import '../../room/data/room_dto.dart';
import '../domain/ride_name_store.dart';

/// [RideNameStore] on the Realtime Database.
///
/// The shared name is written to the room and the summary in one multi-path
/// update, so they can never disagree. A rider's own name is a single field on
/// their history entry. The device's saved copies of the history page and of
/// the ride's details are updated too, so a name shows at once, offline or not.
class RtdbRideNameStore implements RideNameStore {
  RtdbRideNameStore({
    required FirebaseDatabase database,
    required JsonCache cache,
    this.timeout = const Duration(seconds: 10),
  }) : _database = database,
       _cache = cache;

  final FirebaseDatabase _database;
  final JsonCache _cache;
  final Duration timeout;

  @override
  Future<Result<void>> saveSharedName({
    required String code,
    required String name,
  }) async {
    final room = '${RoomPaths.rooms}/$code/${RoomPaths.meta}';
    final summary = RideSummaryPaths.summary(code);
    try {
      await _database
          .ref()
          .update(<String, Object?>{
            '$room/${RoomPaths.metaName}': name,
            '$room/${RoomPaths.metaNamePending}': false,
            '$summary/${RideSummaryPaths.roomName}': name,
            '$summary/${RideSummaryPaths.named}': true,
          })
          .timeout(timeout);
      return const Success(null);
    } on TimeoutException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on FirebaseException catch (e) {
      debugPrint('Saving the ride name failed (${e.code}): ${e.message}');
      return Failed(
        e.code == 'permission-denied'
            ? const AuthFailure(message: 'Only the host can name the ride.')
            : NetworkFailure(cause: e),
      );
    }
  }

  @override
  Future<SharedRideName?> readSharedName(String code) async {
    try {
      final summary = _database.ref(RideSummaryPaths.summary(code));
      final results = await Future.wait([
        summary.child(RideSummaryPaths.roomName).get(),
        summary.child(RideSummaryPaths.named).get(),
      ]).timeout(timeout);
      final name = results[0].value;
      if (name is! String || name.trim().isEmpty) return null;
      // A summary written before names were set later has no flag, and its
      // name is final.
      final named = results[1].value;
      return SharedRideName(name: name, isFinal: named != false);
    } on Object catch (e) {
      debugPrint('Reading the shared ride name failed: $e');
      return null;
    }
  }

  @override
  Future<Result<void>> saveMyName({
    required String uid,
    required String code,
    required String name,
  }) async {
    try {
      final entry = _database.ref(RideHistoryPaths.entry(uid, code));
      final existing = await Future.wait([
        entry.child(RideHistoryPaths.roomName).get(),
        entry.child(RideHistoryPaths.namePending).get(),
      ]).timeout(timeout);
      if (!existing[0].exists) {
        return const Failed(
          NotFoundFailure(message: 'Save this ride to your history first.'),
        );
      }
      await entry
          .update(<String, Object?>{
            RideHistoryPaths.roomName: name,
            // Null removes the "waiting for the host's name" mark. Only sent
            // when there is one: the rules allow removing it, nothing else.
            if (existing[1].exists) RideHistoryPaths.namePending: null,
          })
          .timeout(timeout);
      await _updateCaches(uid: uid, code: code, name: name);
      return const Success(null);
    } on TimeoutException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on FirebaseException catch (e) {
      debugPrint('Renaming the ride failed (${e.code}): ${e.message}');
      return Failed(NetworkFailure(cause: e));
    }
  }

  /// Puts [name] into the device's saved history page and ride details.
  Future<void> _updateCaches({
    required String uid,
    required String code,
    required String name,
  }) async {
    final historyKey = RtdbRideHistoryRepository.cacheKey(uid);
    final history = await _cache.read(historyKey);
    final entries = history?['entries'];
    if (history != null && entries is List) {
      var changed = false;
      for (final entry in entries) {
        if (entry is Map && entry['code'] == code) {
          entry[RideHistoryPaths.roomName] = name;
          entry.remove(RideHistoryPaths.namePending);
          changed = true;
        }
      }
      if (changed) await _cache.write(historyKey, history);
    }

    final detailsKey = RtdbRideDetailsRepository.cacheKey(code);
    final details = await _cache.read(detailsKey);
    final summary = details?['summary'];
    if (details != null && summary is Map) {
      summary[RideSummaryPaths.roomName] = name;
      await _cache.write(detailsKey, details);
    }
  }
}
