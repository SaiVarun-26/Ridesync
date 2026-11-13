import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/route_model.dart';
import '../domain/shared_route_repository.dart';
import 'route_dto.dart';

/// [SharedRouteRepository] stored under `rooms/{code}/route` in the Realtime
/// Database. The security rules allow only the host to write it, and only
/// while the ride is being planned.
class RtdbSharedRouteRepository implements SharedRouteRepository {
  RtdbSharedRouteRepository({required FirebaseDatabase database})
    : _database = database;

  final FirebaseDatabase _database;

  @override
  Stream<PlannedRoute?> watch({required String code}) {
    return _database
        .ref(RoutePaths.route(code))
        .onValue
        .map((event) => RouteDto.fromValue(event.snapshot.value));
  }

  @override
  Future<Result<void>> save({
    required String code,
    required PlannedRoute route,
  }) async {
    try {
      await _database.ref(RoutePaths.route(code)).set(RouteDto.toValue(route));
      return const Success(null);
    } on FirebaseException catch (e) {
      debugPrint('Saving the route failed (${e.code}): ${e.message}');
      return Failed(
        e.code == 'permission-denied'
            ? const AuthFailure(message: 'Only the host can set the route.')
            : NetworkFailure(cause: e),
      );
    }
  }
}
