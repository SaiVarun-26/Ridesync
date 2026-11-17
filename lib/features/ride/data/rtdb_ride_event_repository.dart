import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../auth/domain/auth_repository.dart';
import '../domain/leaderboard/leaderboard.dart';

/// Realtime Database layout for the ride's event log:
/// `rideEvents/{code}/{uid}/{eventId}`. Each rider writes only their own
/// events, so the log holds every event once however many phones saw it.
abstract final class RideEventPaths {
  static String rider(String code, String uid) => 'rideEvents/$code/$uid';

  static const String kind = 'kind';
  static const String mode = 'mode';
  static const String at = 'at';
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';

  const RideEventPaths._();
}

/// Writes this rider's own path events (left, rejoined) to the ride's log.
/// Best effort: a lost write never affects the ride.
class RtdbRideEventRepository {
  RtdbRideEventRepository({
    required FirebaseDatabase database,
    required AuthRepository auth,
  }) : _database = database,
       _auth = auth;

  final FirebaseDatabase _database;
  final AuthRepository _auth;

  Future<void> log({required String code, required RidePathEvent event}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid != event.uid) return;
    try {
      await _database.ref(RideEventPaths.rider(code, uid)).push().set({
        RideEventPaths.kind: event.kind.wireValue,
        RideEventPaths.mode: event.guided ? 'guided' : 'free',
        RideEventPaths.at: ServerValue.timestamp,
        RideEventPaths.latitude: event.point.latitude,
        RideEventPaths.longitude: event.point.longitude,
      });
    } on FirebaseException catch (e) {
      debugPrint('Logging the ride event failed (${e.code}): ${e.message}');
    }
  }
}
