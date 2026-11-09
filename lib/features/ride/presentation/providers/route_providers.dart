import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctions;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/google_maps_config.dart';
import '../../../../core/errors/result.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/cloud_route_repository.dart';
import '../../data/google_places_repository.dart';
import '../../domain/geo_point.dart';
import '../../domain/places_repository.dart';
import '../../domain/route_model.dart';
import '../../domain/route_repository.dart';
import 'ride_init_providers.dart';

/// Region of the `getRoute` function, matching the Realtime Database.
const String _functionsRegion = 'asia-southeast1';

/// Cloud Functions client for the app's region, overridable in tests.
final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: _functionsRegion);
});

/// Destination search.
final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return GooglePlacesRepository(
    apiKey: GoogleMapsConfig.placesApiKey,
    androidPackage: GoogleMapsConfig.androidPackage,
    androidCertSha1: GoogleMapsConfig.androidCertSha1,
    iosBundleId: GoogleMapsConfig.iosBundleId,
  );
});

/// Route generation and sync.
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return CloudRouteRepository(
    functions: ref.watch(firebaseFunctionsProvider),
    database: ref.watch(firebaseDatabaseProvider),
  );
});

/// The live planned route for a room; `null` until the host generates one.
final plannedRouteProvider =
    StreamProvider.autoDispose.family<PlannedRoute?, String>((ref, code) {
  return ref.watch(routeRepositoryProvider).watchRoute(code: code);
});

/// The host's planning actions for a room.
final guidedPlanningControllerProvider = NotifierProvider.autoDispose
    .family<GuidedPlanningController, PlanningState, String>(
  GuidedPlanningController.new,
);

/// What the planning screen shows about the host's in-flight actions.
class PlanningState {
  const PlanningState({
    this.pendingDestination,
    this.isStarting = false,
    this.error,
    this.errorId = 0,
  });

  /// Name of the destination whose route is being generated, if any.
  final String? pendingDestination;

  /// Whether a Start Ride request is in flight.
  final bool isStarting;

  /// The latest error to show the host.
  final String? error;

  /// Increments with every new error, so the same message can be shown twice.
  final int errorId;

  bool get isGenerating => pendingDestination != null;
}

/// Runs the host's planning: resolving a chosen place, generating the shared
/// route, and starting the ride. Riders never call it; their screens simply
/// observe the room and the route.
class GuidedPlanningController extends Notifier<PlanningState> {
  GuidedPlanningController(this._code);

  final String _code;
  GeoPoint? _lastFix;

  /// How long to wait for the host's current position.
  static const Duration _fixTimeout = Duration(seconds: 10);

  /// Shorter wait when the position is only used to rank search results.
  static const Duration _biasTimeout = Duration(seconds: 3);

  @override
  PlanningState build() => const PlanningState();

  /// The host's position for ranking search results nearby, if available.
  Future<GeoPoint?> searchBias() async {
    return _lastFix ??= await ref
        .read(locationRepositoryProvider)
        .currentPosition(timeout: _biasTimeout);
  }

  /// Resolves [suggestion], generates the route from the host's position, and
  /// shares it with every rider. Replaces any earlier destination.
  Future<void> chooseDestination(PlaceSuggestion suggestion) async {
    if (state.isGenerating || state.isStarting) return;
    state = PlanningState(
      pendingDestination: suggestion.primaryText,
      errorId: state.errorId,
    );

    final details =
        await ref.read(placesRepositoryProvider).details(suggestion.placeId);
    if (!ref.mounted) return;
    final PlaceDetails destination;
    switch (details) {
      case Success(:final value):
        destination = value;
      case Failed(:final failure):
        return _fail(failure.message);
    }

    final origin = await ref
        .read(locationRepositoryProvider)
        .currentPosition(timeout: _fixTimeout);
    if (!ref.mounted) return;
    if (origin == null) {
      return _fail('Waiting for your GPS. Try again in a moment.');
    }
    _lastFix = origin;

    final result = await ref.read(routeRepositoryProvider).generateRoute(
          code: _code,
          origin: origin,
          destination: destination,
        );
    if (!ref.mounted) return;
    switch (result) {
      case Success():
        state = PlanningState(errorId: state.errorId);
      case Failed(:final failure):
        _fail(failure.message);
    }
  }

  /// Starts the ride for everyone. Requires a generated route; the room
  /// repository and the security rules check the rest.
  Future<void> startRide() async {
    if (state.isGenerating || state.isStarting) return;
    final route = ref.read(plannedRouteProvider(_code)).value;
    if (route == null) return _fail('Choose a destination first.');

    state = PlanningState(isStarting: true, errorId: state.errorId);
    final result =
        await ref.read(roomRepositoryProvider).startGuidedRide(code: _code);
    if (!ref.mounted) return;
    // On success the room moves to riding and every screen plays the start
    // transition, so the button stays busy until then.
    if (result case Failed(:final failure)) _fail(failure.message);
  }

  void _fail(String message) {
    state = PlanningState(error: message, errorId: state.errorId + 1);
  }
}
