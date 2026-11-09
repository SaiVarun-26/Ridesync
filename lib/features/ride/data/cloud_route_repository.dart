import 'package:cloud_functions/cloud_functions.dart'
    show FirebaseFunctions, FirebaseFunctionsException;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/geo_point.dart';
import '../domain/places_repository.dart';
import '../domain/route_model.dart';
import '../domain/route_repository.dart';
import 'route_dto.dart';

/// [RouteRepository] that generates routes with the `getRoute` Cloud Function
/// and observes them in the Realtime Database.
///
/// The function verifies the caller is the host, calls the Routes API with a
/// server-side key, and writes the route to the room, so every rider receives
/// it through [watchRoute].
class CloudRouteRepository implements RouteRepository {
  CloudRouteRepository({
    required FirebaseFunctions functions,
    required FirebaseDatabase database,
  })  : _functions = functions,
        _database = database;

  final FirebaseFunctions _functions;
  final FirebaseDatabase _database;

  /// The single V1 Cloud Function.
  static const String _getRoute = 'getRoute';

  @override
  Stream<PlannedRoute?> watchRoute({required String code}) {
    return _database
        .ref(RoutePaths.route(code))
        .onValue
        .map((event) => RouteDto.fromValue(event.snapshot.value));
  }

  @override
  Future<Result<PlannedRoute>> generateRoute({
    required String code,
    required GeoPoint origin,
    required PlaceDetails destination,
  }) async {
    try {
      final result = await _functions.httpsCallable(_getRoute).call<Object?>(
        <String, Object?>{
          'roomCode': code,
          'origin': _point(origin),
          'destination': <String, Object?>{
            ..._point(destination.location),
            'name': destination.name,
            'address': destination.address,
          },
        },
      );
      final route = RouteDto.fromValue(result.data);
      if (route == null) {
        return const Failed(
          UnexpectedFailure(message: 'The route came back incomplete.'),
        );
      }
      return Success(route);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('getRoute failed (${e.code}): ${e.message}');
      return Failed(_mapFunctionsException(e));
    } catch (e, stack) {
      debugPrint('Unexpected route error: $e\n$stack');
      return Failed(UnexpectedFailure(cause: e));
    }
  }

  static Map<String, Object?> _point(GeoPoint point) => <String, Object?>{
        'latitude': point.latitude,
        'longitude': point.longitude,
      };

  static Failure _mapFunctionsException(FirebaseFunctionsException e) {
    final message = e.message;
    return switch (e.code) {
      'unauthenticated' || 'permission-denied' => AuthFailure(
          message: message ?? 'Only the host can choose the destination.',
          cause: e,
        ),
      'not-found' => NotFoundFailure(
          message: message ?? 'No route found to that destination.',
          cause: e,
        ),
      'failed-precondition' => ConflictFailure(
          message: message ?? 'This ride is not being planned.',
          cause: e,
        ),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(cause: e),
      _ => UnexpectedFailure(
          message: 'Could not generate the route. Please try again.',
          cause: e,
        ),
    };
  }
}
