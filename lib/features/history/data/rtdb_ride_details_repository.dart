import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../ride/data/ride_stats_dto.dart';
import '../../ride/data/ride_summary_dto.dart';
import '../../ride/domain/polyline.dart';
import '../../ride/domain/speed_codec.dart';
import '../domain/ride_details.dart';
import '../domain/ride_details_repository.dart';
import 'json_cache.dart';
import 'ride_history_dto.dart';

/// [RideDetailsRepository] on the Realtime Database.
///
/// Reads the ride's summary and every rider's route once (no listeners) and
/// keeps a copy on the device. Routes and their speeds are stored as the
/// compact encoded strings they arrive as, and decoded when loaded.
class RtdbRideDetailsRepository implements RideDetailsRepository {
  RtdbRideDetailsRepository({
    required FirebaseDatabase database,
    required JsonCache cache,
    String? Function()? currentUid,
    this.timeout = const Duration(seconds: 10),
  }) : _database = database,
       _cache = cache,
       _currentUid = currentUid;

  final FirebaseDatabase _database;
  final JsonCache _cache;
  final String? Function()? _currentUid;
  final Duration timeout;

  /// The name the signed-in rider gave this ride, if they renamed it. It
  /// stands in for the shared name wherever the ride is shown, so the details,
  /// the recap and the share card all agree with their history.
  Future<String?> _ownName(String code) async {
    final uid = _currentUid?.call();
    if (uid == null) return null;
    try {
      final entry = _database.ref(RideHistoryPaths.entry(uid, code));
      final results = await Future.wait([
        entry.child(RideHistoryPaths.roomName).get(),
        entry.child(RideHistoryPaths.namePending).get(),
      ]).timeout(timeout);
      // A copy still waiting for the host's name holds only a placeholder,
      // which must never hide the host's real name.
      if (results[1].value == true) return null;
      final value = results[0].value;
      return value is String && value.trim().isNotEmpty ? value : null;
    } on Object catch (e) {
      debugPrint('Reading the rider\'s own ride name failed: $e');
      return null;
    }
  }

  /// Where ride [code]'s details are kept on the device.
  static String cacheKey(String code) => 'details_$code';

  @override
  Future<Result<RideDetails>> load(String code) async {
    try {
      final summaryFuture = _database
          .ref(RideSummaryPaths.summary(code))
          .get()
          .timeout(timeout);
      final routesFuture = _safe(
        _database.ref(RideStatsPaths.routes(code)).get().timeout(timeout),
      );
      final summarySnapshot = await summaryFuture;
      final routesSnapshot = await routesFuture;

      var summary = RideSummaryDto.fromValue(code, summarySnapshot.value);
      if (summary == null) {
        return const Failed(
          NotFoundFailure(message: 'Ride results not found.'),
        );
      }
      final own = await _ownName(code);
      if (own != null && own != summary.roomName) summary = summary.withName(own);
      final encoded = _encodedRoutes(routesSnapshot?.value);

      await _cache.write(cacheKey(code), {
        'summary': RideSummaryDto.toValue(summary),
        'routes': encoded,
      });
      return Success(RideDetails(summary: summary, routes: _decode(encoded)));
    } on TimeoutException catch (e) {
      return _fromCache(code, e);
    } on FirebaseException catch (e) {
      debugPrint('Loading ride details failed (${e.code}): ${e.message}');
      return _fromCache(code, e);
    }
  }

  /// Routes are a bonus: if only they fail, the summary still shows.
  Future<DataSnapshot?> _safe(Future<DataSnapshot> future) async {
    try {
      return await future;
    } on Object catch (e) {
      debugPrint('Loading ride routes failed: $e');
      return null;
    }
  }

  Future<Result<RideDetails>> _fromCache(String code, Object cause) async {
    final json = await _cache.read(cacheKey(code));
    final summary = RideSummaryDto.fromValue(code, json?['summary']);
    if (summary == null) return Failed(NetworkFailure(cause: cause));
    return Success(
      RideDetails(
        summary: summary,
        routes: _decode(_encodedRoutes(json?['routes'])),
        fromCache: true,
      ),
    );
  }

  /// Each rider's encoded route: `{polyline, speeds?}`, by uid.
  static Map<String, Object?> _encodedRoutes(Object? value) {
    final result = <String, Object?>{};
    if (value is! Map) return result;
    value.forEach((uid, route) {
      if (uid is! String || route is! Map) return;
      final polyline = route[RideStatsPaths.polyline];
      if (polyline is! String || polyline.isEmpty) return;
      final speeds = route[RideStatsPaths.speeds];
      result[uid] = <String, Object?>{
        RideStatsPaths.polyline: polyline,
        if (speeds is String && speeds.isNotEmpty)
          RideStatsPaths.speeds: speeds,
      };
    });
    return result;
  }

  static Map<String, RiderRoute> _decode(Map<String, Object?> encoded) {
    final routes = <String, RiderRoute>{};
    encoded.forEach((uid, route) {
      if (route is! Map) return;
      final points = decodePolyline(route[RideStatsPaths.polyline]! as String);
      if (points.isEmpty) return;
      final speeds = route[RideStatsPaths.speeds];
      routes[uid] = RiderRoute(
        points: points,
        speedsMps: speeds is String ? SpeedCodec.decode(speeds) : const [],
      );
    });
    return routes;
  }
}
