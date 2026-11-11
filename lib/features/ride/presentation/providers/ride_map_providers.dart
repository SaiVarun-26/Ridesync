import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/background_tracking_service.dart';
import '../../data/rtdb_live_location_repository.dart';
import '../../data/rtdb_ride_stats_repository.dart';
import '../../domain/live_location_repository.dart';
import '../../domain/stats/ride_stats_repository.dart';
import '../ride_map_controller.dart';

/// Shared rider positions for live rides.
final liveLocationRepositoryProvider = Provider<LiveLocationRepository>((ref) {
  return RtdbLiveLocationRepository(
    database: ref.watch(firebaseDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
  );
});

/// Saves and restores each rider's ride record (statistics and route).
final rideStatsRepositoryProvider = Provider<RideStatsRepository>((ref) {
  return RtdbRideStatsRepository(
    database: ref.watch(firebaseDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
  );
});

/// The Android foreground-service that keeps tracking alive in the background.
final backgroundTrackingServiceProvider = Provider<BackgroundTrackingService>((
  ref,
) {
  return BackgroundTrackingService();
});

/// The live map for a room: this rider's GPS, every visible rider, and
/// their trails. Auto-disposed, so GPS and sharing stop when the map closes.
final rideMapControllerProvider = NotifierProvider.autoDispose
    .family<RideMapController, RideMapState, String>(RideMapController.new);
