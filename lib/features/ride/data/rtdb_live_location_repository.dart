import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/geo_point.dart';
import '../domain/live_location_repository.dart';
import '../domain/location_fix.dart';
import '../domain/rider_location.dart';

/// Realtime Database layout for live rider positions:
/// `liveLocations/{roomCode}/{uid}`.
abstract final class LiveLocationPaths {
  static String room(String code) => 'liveLocations/$code';

  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String heading = 'heading';
  static const String speed = 'speed';
  static const String lastUpdated = 'lastUpdated';

  const LiveLocationPaths._();
}

/// [LiveLocationRepository] on the Realtime Database.
///
/// Uses child events rather than whole-node snapshots, so each GPS update
/// costs one small message per listener regardless of group size.
class RtdbLiveLocationRepository implements LiveLocationRepository {
  RtdbLiveLocationRepository({
    required FirebaseDatabase database,
    required AuthRepository auth,
  })  : _database = database,
        _auth = auth;

  final FirebaseDatabase _database;
  final AuthRepository _auth;

  static const Failure _signedOut =
      AuthFailure(message: 'You must be signed in.');

  /// Highest speed the rules accept (150 m/s, 540 km/h); anything faster is a
  /// GPS glitch.
  static const double maxSpeedMps = 150;
  static const double _maxHeading = 360;

  @override
  Stream<RiderLocationChange> watchChanges({required String code}) {
    final ref = _database.ref(LiveLocationPaths.room(code));
    late final StreamController<RiderLocationChange> controller;
    final subscriptions = <StreamSubscription<DatabaseEvent>>[];

    void onUpsert(DatabaseEvent event) {
      final location = _parse(event.snapshot);
      if (location != null) controller.add(RiderLocationUpdated(location));
    }

    controller = StreamController<RiderLocationChange>(
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
                if (uid != null) controller.add(RiderLocationRemoved(uid));
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

  @override
  Future<Result<void>> publish({
    required String code,
    required LocationFix fix,
  }) {
    // Clamped to the ranges the security rules accept, so one noisy GPS
    // reading cannot get an update rejected.
    return _write((uid) => _myRef(code, uid).set(<String, Object?>{
          LiveLocationPaths.latitude: fix.point.latitude,
          LiveLocationPaths.longitude: fix.point.longitude,
          LiveLocationPaths.heading:
              (fix.headingDegrees ?? 0).clamp(0, _maxHeading).toDouble(),
          LiveLocationPaths.speed:
              (fix.speedMps ?? 0).clamp(0, maxSpeedMps).toDouble(),
          LiveLocationPaths.lastUpdated: ServerValue.timestamp,
        }));
  }

  @override
  Future<Result<void>> removeOnDisconnect({required String code}) {
    return _write((uid) => _myRef(code, uid).onDisconnect().remove());
  }

  @override
  Future<Result<void>> clear({required String code}) {
    return _write((uid) async {
      final ref = _myRef(code, uid);
      await ref.onDisconnect().cancel();
      await ref.remove();
    });
  }

  DatabaseReference _myRef(String code, String uid) =>
      _database.ref(LiveLocationPaths.room(code)).child(uid);

  Future<Result<void>> _write(Future<void> Function(String uid) action) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Failed(_signedOut);
    try {
      await action(uid);
      return const Success(null);
    } on FirebaseException catch (e) {
      debugPrint('Live location write failed (${e.code}): ${e.message}');
      return Failed(
        e.code == 'permission-denied'
            ? const AuthFailure(message: 'You are not riding in this room.')
            : NetworkFailure(cause: e),
      );
    }
  }

  static RiderLocation? _parse(DataSnapshot snapshot) {
    final uid = snapshot.key;
    final value = snapshot.value;
    if (uid == null || value is! Map) return null;
    final latitude = value[LiveLocationPaths.latitude];
    final longitude = value[LiveLocationPaths.longitude];
    if (latitude is! num || longitude is! num) return null;
    final heading = value[LiveLocationPaths.heading];
    final speed = value[LiveLocationPaths.speed];
    final updated = value[LiveLocationPaths.lastUpdated];
    return RiderLocation(
      uid: uid,
      point: GeoPoint(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
      headingDegrees: heading is num ? heading.toDouble() : null,
      speedMps: speed is num ? speed.toDouble() : null,
      updatedAt: updated is num ? updated.toInt() : null,
    );
  }
}
