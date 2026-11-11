import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../room/domain/room_status.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/rtdb_ride_summary_repository.dart';
import '../../domain/completion/ride_completion_service.dart';
import '../../domain/completion/ride_end_stage.dart';
import '../../domain/summary/ride_summary_repository.dart';
import 'ride_map_providers.dart';

/// Saves and reads the finished ride's summary.
final rideSummaryRepositoryProvider = Provider<RideSummaryRepository>((ref) {
  return RtdbRideSummaryRepository(
    database: ref.watch(firebaseDatabaseProvider),
  );
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

/// Where the host's End Ride action stands.
class RideEndState {
  const RideEndState({
    this.isEnding = false,
    this.stage,
    this.error,
    this.errorId = 0,
  });

  /// Whether ending the ride is in progress.
  final bool isEnding;

  /// The step the host's ending has reached; `null` when not ending.
  final RideEndStage? stage;

  /// The latest error to show the host.
  final String? error;

  /// Increments with every new error, so the same message can show twice.
  final int errorId;
}

/// What the ending overlay should show.
class RideEndProgress {
  const RideEndProgress({required this.stage, this.error});

  final RideEndStage stage;

  /// Set when the host's ending failed and can be retried.
  final String? error;

  /// What to show for a rider in a room with [status].
  ///
  /// [end] is this device's own End Ride state (only the host ever starts
  /// one), and [ownRecordSaved] tells whether this device has finished saving
  /// its own final record. Returns `null` when nothing should be shown.
  static RideEndProgress? of({
    required RoomStatus? status,
    required bool isHost,
    required RideEndState end,
    required bool ownRecordSaved,
  }) {
    if (status == RoomStatus.ended) {
      return const RideEndProgress(stage: RideEndStage.complete);
    }
    if (isHost) {
      if (end.error != null && !end.isEnding) {
        return RideEndProgress(
          stage: end.stage ?? RideEndStage.ending,
          error: end.error,
        );
      }
      if (end.isEnding) {
        return RideEndProgress(stage: end.stage ?? RideEndStage.ending);
      }
      return null;
    }
    if (status == RoomStatus.ending) {
      return RideEndProgress(
        stage: ownRecordSaved
            ? RideEndStage.generatingSummary
            : RideEndStage.savingRiders,
      );
    }
    return null;
  }
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
  /// state stays busy until then. On failure the host can try again.
  Future<void> endRide() async {
    if (state.isEnding) return;
    final service = ref.read(rideCompletionServiceProvider);
    state = RideEndState(
      isEnding: true,
      stage: RideEndStage.ending,
      errorId: state.errorId,
    );

    final result = await service.endRide(
      code: _code,
      onStage: (stage) {
        if (!ref.mounted) return;
        state = RideEndState(
          isEnding: true,
          stage: stage,
          errorId: state.errorId,
        );
      },
    );
    if (!ref.mounted) return;
    if (result case Failed(:final failure)) {
      state = RideEndState(
        stage: state.stage,
        error: failure.message,
        errorId: state.errorId + 1,
      );
    }
  }

  /// Hides a failed ending so the host can start it again from the panel.
  void dismissError() {
    if (state.isEnding) return;
    state = RideEndState(errorId: state.errorId);
  }
}
