import '../../../core/errors/result.dart';
import 'route_model.dart';

/// Contract for the planned route shared with every rider in a room.
abstract interface class SharedRouteRepository {
  /// The room's planned route, live. Emits `null` until one is saved.
  Stream<PlannedRoute?> watch({required String code});

  /// Saves [route] for room [code], replacing any earlier one. Host only.
  Future<Result<void>> save({required String code, required PlannedRoute route});
}
