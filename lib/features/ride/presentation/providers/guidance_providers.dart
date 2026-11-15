import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../room/presentation/providers/room_providers.dart';
import '../../data/osm_route_repository.dart';
import '../../data/rtdb_shared_route_repository.dart';
import '../../domain/geo_point.dart';
import '../../domain/guidance/route_guide.dart';
import '../../domain/guidance/route_guide_cache.dart';
import '../../domain/route_model.dart';
import '../../domain/route_repository.dart';
import '../../domain/shared_route_repository.dart';
import '../guidance/guidance_controller.dart';
import '../guidance/route_planner_controller.dart';
import 'ride_init_providers.dart';

/// Destination search and routing (host only, while planning).
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return OsmRouteRepository();
});

/// The planned route every rider in a room shares.
final sharedRouteRepositoryProvider = Provider<SharedRouteRepository>((ref) {
  return RtdbSharedRouteRepository(
    database: ref.watch(firebaseDatabaseProvider),
  );
});

/// Room [code]'s planned route, live; `null` until the host saves one.
final plannedRouteProvider = StreamProvider.autoDispose
    .family<PlannedRoute?, String>((ref, code) {
      return ref.watch(sharedRouteRepositoryProvider).watch(code: code);
    });

/// Room [code]'s route, analysed for guidance (built off the UI thread and
/// cached); `null` until there is a route.
final routeGuideProvider = FutureProvider.autoDispose
    .family<RouteGuide?, String>((ref, code) async {
      final route = await ref.watch(plannedRouteProvider(code).future);
      if (route == null) return null;
      return RouteGuideCache.instance.guideFor(route);
    });

/// This device's position, once, for centring the planning map.
final currentPositionProvider = FutureProvider.autoDispose<GeoPoint?>((ref) {
  return ref
      .read(locationRepositoryProvider)
      .currentPosition(timeout: const Duration(seconds: 10));
});

/// The host's planning session for room [code].
final routePlannerControllerProvider = NotifierProvider.autoDispose
    .family<RoutePlannerController, RoutePlannerState, String>(
      RoutePlannerController.new,
    );

/// Live guidance for this rider in room [code]'s guided ride.
final guidanceControllerProvider = NotifierProvider.autoDispose
    .family<GuidanceController, GuidanceState, String>(
      GuidanceController.new,
    );
