import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/geo_point.dart';
import '../domain/polyline.dart';
import '../domain/stats/ride_stats.dart';
import '../domain/stats/ride_stats_repository.dart';
import 'ride_stats_dto.dart';

/// [RideStatsRepository] on the Realtime Database.
///
/// The database's offline persistence is enabled at startup, so writes made
/// while the rider has no signal are stored on the device and delivered when
/// the connection returns, even across an app restart.
class RtdbRideStatsRepository implements RideStatsRepository {
  RtdbRideStatsRepository({
    required FirebaseDatabase database,
    required AuthRepository auth,
  })  : _database = database,
        _auth = auth;

  final FirebaseDatabase _database;
  final AuthRepository _auth;

  static const Failure _signedOut =
      AuthFailure(message: 'You must be signed in.');

  @override
  Future<Result<RideStats?>> loadMine({required String code}) {
    return _run<RideStats?>((uid) async {
      final snapshot =
          await _database.ref(RideStatsPaths.stats(code)).child(uid).get();
      return RideStatsDto.fromValue(snapshot.value);
    });
  }

  @override
  Future<Result<void>> saveMine({
    required String code,
    required RideStats stats,
  }) {
    return _run<void>((uid) {
      return _database
          .ref(RideStatsPaths.stats(code))
          .child(uid)
          .set(RideStatsDto.toValue(stats, ServerValue.timestamp));
    });
  }

  @override
  Future<Result<List<GeoPoint>>> loadMyRoute({required String code}) {
    return _run<List<GeoPoint>>((uid) async {
      final snapshot =
          await _database.ref(RideStatsPaths.routes(code)).child(uid).get();
      final value = snapshot.value;
      if (value is! Map) return const <GeoPoint>[];
      final encoded = value[RideStatsPaths.polyline];
      return encoded is String ? decodePolyline(encoded) : const <GeoPoint>[];
    });
  }

  @override
  Future<Result<void>> saveMyRoute({
    required String code,
    required List<GeoPoint> route,
  }) {
    return _run<void>((uid) {
      return _database.ref(RideStatsPaths.routes(code)).child(uid).set(
        <String, Object?>{
          RideStatsPaths.polyline: encodePolyline(route),
          RideStatsPaths.updatedAt: ServerValue.timestamp,
        },
      );
    });
  }

  @override
  Stream<Map<String, RideStats>> watchAll({required String code}) {
    final ref = _database.ref(RideStatsPaths.stats(code));
    final current = <String, RideStats>{};
    final subscriptions = <StreamSubscription<DatabaseEvent>>[];
    late final StreamController<Map<String, RideStats>> controller;

    void emit() => controller.add(Map<String, RideStats>.of(current));

    void onUpsert(DatabaseEvent event) {
      final uid = event.snapshot.key;
      final stats = RideStatsDto.fromValue(event.snapshot.value);
      if (uid == null || stats == null) return;
      current[uid] = stats;
      emit();
    }

    controller = StreamController<Map<String, RideStats>>(
      onListen: () {
        subscriptions
          ..add(ref.onChildAdded.listen(onUpsert, onError: controller.addError))
          ..add(
            ref.onChildChanged.listen(onUpsert, onError: controller.addError),
          )
          ..add(
            ref.onChildRemoved.listen(
              (event) {
                final uid = event.snapshot.key;
                if (uid != null && current.remove(uid) != null) emit();
              },
              onError: controller.addError,
            ),
          );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  Future<Result<T>> _run<T>(Future<T> Function(String uid) action) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Failed(_signedOut);
    try {
      return Success(await action(uid));
    } on FirebaseException catch (e) {
      debugPrint('Ride record request failed (${e.code}): ${e.message}');
      return Failed(
        e.code == 'permission-denied'
            ? const AuthFailure(message: 'You are not riding in this room.')
            : NetworkFailure(cause: e),
      );
    }
  }
}
