import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/stats/ride_stats.dart';
import 'ride_map_providers.dart';

/// Every rider's saved statistics in room `code`, live. Only listened to while
/// a rider's info card is open, so it costs nothing the rest of the ride.
final roomRideStatsProvider = StreamProvider.autoDispose
    .family<Map<String, RideStats>, String>((ref, code) {
  return ref.watch(rideStatsRepositoryProvider).watchAll(code: code);
});
