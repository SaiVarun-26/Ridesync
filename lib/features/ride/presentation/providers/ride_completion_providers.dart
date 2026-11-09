import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/rtdb_ride_summary_repository.dart';
import '../../domain/completion/ride_completion_service.dart';
import '../../domain/summary/ride_summary_repository.dart';
import 'ride_map_providers.dart';

/// Saves and reads the finished ride's summary.
final rideSummaryRepositoryProvider = Provider<RideSummaryRepository>((ref) {
  return RtdbRideSummaryRepository(database: ref.watch(firebaseDatabaseProvider));
});

/// Ends a ride from the host's side.
final rideCompletionServiceProvider = Provider<RideCompletionService>((ref) {
  return RideCompletionService(
    rooms: ref.watch(roomRepositoryProvider),
    stats: ref.watch(rideStatsRepositoryProvider),
    summaries: ref.watch(rideSummaryRepositoryProvider),
  );
});

/// The host's End Ride action for a room.
final rideEndControllerProvider = NotifierProvider.autoDispose
    .family<RideEndController, RideEndState, String>(RideEndController.new);

/// What the End Ride button shows.
class RideEndState {
  const RideEndState({this.isEnding = false, this.error, this.errorId = 0});

  /// Whether ending the ride is in progress.
  final bool isEnding;

  /// The latest error to show the host.
  final String? error;

  /// Increments with every new error, so the same message can show twice.
  final int errorId;
}

/// Runs End Ride. The widget only shows [RideEndState]; the ending itself is
/// done by [RideCompletionService].
class RideEndController extends Notifier<RideEndState> {
  RideEndController(this._code);

  final String _code;

  @override
  RideEndState build() => const RideEndState();

  /// Ends the ride for everyone. On success the room becomes `ended` and every
  /// screen, including this one, follows the room to the results, so the
  /// button stays busy until then. On failure the host can try again.
  Future<void> endRide() async {
    if (state.isEnding) return;
    final service = ref.read(rideCompletionServiceProvider);
    state = RideEndState(isEnding: true, errorId: state.errorId);

    final result = await service.endRide(code: _code);
    if (!ref.mounted) return;
    if (result case Failed(:final failure)) {
      state = RideEndState(error: failure.message, errorId: state.errorId + 1);
    }
  }
}
