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

/// [RideDetailsRepository] on the Realtime Database.
///
/// Reads the ride's summary and every rider's route once (no listeners) and
/// keeps a copy on the device. Routes and their speeds are stored as the
/// compact encoded strings they arrive as, and decoded when loaded.
class RtdbRideDetailsRepository implements RideDetailsRepository {
  RtdbRideDetailsRepository({
    required FirebaseDatabase database,
    required JsonCache cache,
    this.timeout = const Duration(seconds: 10),
  }) : _database = database,
       _cache = cache;

  final FirebaseDatabase _database;
  final JsonCache _cache;
  final Duration timeout;

  static String _cacheKey(String code) => 'details_$code';

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

      final summary = RideSummaryDto.fromValue(code, summarySnapshot.value);
      if (summary == null) {
        return const Failed(
          NotFoundFailure(message: 'Ride results not found.'),
        );
      }
      final encoded = _encodedRoutes(routesSnapshot?.value);

      await _cache.write(_cacheKey(code), {
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
    final json = await _cache.read(_cacheKey(code));
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
