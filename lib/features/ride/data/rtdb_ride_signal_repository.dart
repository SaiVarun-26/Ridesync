import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/geo_point.dart';
import '../domain/safety/ride_signal.dart';
import '../domain/safety/ride_signal_repository.dart';

/// Realtime Database layout for safety signals:
/// `rooms/{code}/signals/{uid}`. The security rules check exactly these
/// fields.
abstract final class RideSignalPaths {
  static String room(String code) => 'rooms/$code/signals';

  static const String kind = 'kind';
  static const String at = 'at';
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';

  const RideSignalPaths._();
}

/// [RideSignalRepository] on the Realtime Database. Every rider owns one small
/// node; the whole set is a few hundred bytes, so it is watched as one value.
class RtdbRideSignalRepository implements RideSignalRepository {
  RtdbRideSignalRepository({
    required FirebaseDatabase database,
    required AuthRepository auth,
  }) : _database = database,
       _auth = auth;

  final FirebaseDatabase _database;
  final AuthRepository _auth;

  @override
  Stream<Map<String, RideSignal>> watch({required String code}) {
    return _database
        .ref(RideSignalPaths.room(code))
        .onValue
        .map((event) => parse(event.snapshot.value));
  }

  @override
  Future<Result<void>> send({
    required String code,
    required RideSignalKind kind,
    GeoPoint? at,
  }) {
    return _write(
      (uid) => _database.ref(RideSignalPaths.room(code)).child(uid).set({
        RideSignalPaths.kind: kind.wireValue,
        RideSignalPaths.at: ServerValue.timestamp,
        if (at != null) RideSignalPaths.latitude: at.latitude,
        if (at != null) RideSignalPaths.longitude: at.longitude,
      }),
    );
  }

  @override
  Future<Result<void>> clear({required String code}) {
    return _write(
      (uid) => _database.ref(RideSignalPaths.room(code)).child(uid).remove(),
    );
  }

  Future<Result<void>> _write(Future<void> Function(String uid) action) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Failed(AuthFailure(message: 'You must be signed in.'));
    }
    try {
      await action(uid);
      return const Success(null);
    } on FirebaseException catch (e) {
      debugPrint('Ride signal write failed (${e.code}): ${e.message}');
      return Failed(
        e.code == 'permission-denied'
            ? const ConflictFailure(
                message: 'Signals can only be sent during the ride.',
              )
            : NetworkFailure(cause: e),
      );
    }
  }

  /// Every well-formed signal in [value], by uid.
  @visibleForTesting
  static Map<String, RideSignal> parse(Object? value) {
    if (value is! Map) return const {};
    final result = <String, RideSignal>{};
    value.forEach((key, raw) {
      if (key is! String || raw is! Map) return;
      final kind = RideSignalKind.fromWire(raw[RideSignalPaths.kind]);
      final at = raw[RideSignalPaths.at];
      if (kind == null || at is! num) return;
      final lat = raw[RideSignalPaths.latitude];
      final lng = raw[RideSignalPaths.longitude];
      result[key] = RideSignal(
        uid: key,
        kind: kind,
        sentAtMs: at.toInt(),
        point: lat is num && lng is num
            ? GeoPoint(latitude: lat.toDouble(), longitude: lng.toDouble())
            : null,
      );
    });
    return result;
  }
}
