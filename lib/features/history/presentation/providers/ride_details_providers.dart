import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/rtdb_ride_details_repository.dart';
import '../../domain/ride_details.dart';
import '../../domain/ride_details_repository.dart';
import 'ride_history_providers.dart';

/// Loads a finished ride's full results.
final rideDetailsRepositoryProvider = Provider<RideDetailsRepository>((ref) {
  return RtdbRideDetailsRepository(
    database: ref.watch(firebaseDatabaseProvider),
    cache: ref.watch(rideCacheProvider),
  );
});

/// The results of the ride in room `code`, read once when the details screen
/// opens and released when it closes. A failure surfaces as an error whose
/// value is the [Failure].
final rideDetailsProvider = FutureProvider.autoDispose
    .family<RideDetails, String>((ref, code) async {
      final result = await ref.watch(rideDetailsRepositoryProvider).load(code);
      return switch (result) {
        Success(:final value) => value,
        Failed(:final failure) => throw failure,
      };
    });
