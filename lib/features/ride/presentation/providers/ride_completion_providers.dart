import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../history/presentation/providers/ride_history_providers.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../naming/domain/ride_title_generator.dart';
import '../../../naming/presentation/naming_providers.dart';
import '../../../room/domain/room_status.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/rtdb_ride_summary_repository.dart';
import '../../domain/completion/ride_completion_service.dart';
import '../../domain/completion/ride_end_stage.dart';
import '../../domain/summary/ride_summary_repository.dart';
import 'pending_upload_providers.dart';
import 'ride_map_providers.dart';

/// Saves and reads the finished ride's summary.
final rideSummaryRepositoryProvider = Provider<RideSummaryRepository>((ref) {
  return RtdbRideSummaryRepository(
    database: ref.watch(firebaseDatabaseProvider),
  );
});

/// Finishes one rider's ride.
final rideCompletionServiceProvider = Provider<RideCompletionService>((ref) {
  return RideCompletionService(
    rooms: ref.watch(roomRepositoryProvider),
    stats: ref.watch(rideStatsRepositoryProvider),
    summaries: ref.watch(rideSummaryRepositoryProvider),
    history: ref.watch(rideHistoryRepositoryProvider),
  );
});

/// This rider's End Ride action for a room.
final rideEndControllerProvider = NotifierProvider.autoDispose
    .family<RideEndController, RideEndState, String>(RideEndController.new);

/// How this rider ended their ride.
enum RideEndTrigger {
  /// They tapped End Ride (or End Ride Now).
  manual,

  /// The auto-end countdown ran out.
  automatic,
}

/// Where this rider's End Ride stands.
class RideEndState {
  const RideEndState({
    this.isEnding = false,
    this.stage,
    this.error,
    this.errorId = 0,
    this.completed = false,
    this.trigger,
  });

  /// Whether ending this rider's ride is in progress.
  final bool isEnding;

  /// The step the ending has reached; `null` when not ending.
  final RideEndStage? stage;

  /// The latest error to show.
  final String? error;

  /// Increments with every new error, so the same message can show twice.
  final int errorId;

  /// Whether this rider's ride is finished and published.
  final bool completed;

  /// How the ending was started, once it was.
  final RideEndTrigger? trigger;
}

/// What the ending overlay should show.
class RideEndProgress {
  const RideEndProgress({required this.stage, this.error});

  final RideEndStage stage;

  /// Set when ending failed and can be retried.
  final String? error;

  /// What to show for this rider in a room with [status].
  ///
  /// [end] is this rider's own End Ride state. [ownRecordSaved] tells whether
  /// this device has finished saving its final record, for a rider whose
  /// room is being closed while they were away. Returns `null` when nothing
  /// should be shown.
  static RideEndProgress? of({
    required RoomStatus? status,
    required RideEndState end,
    required bool ownRecordSaved,
  }) {
    if (status == RoomStatus.ended || end.completed) {
      return const RideEndProgress(stage: RideEndStage.complete);
    }
    if (end.error != null && !end.isEnding) {
      return RideEndProgress(
        stage: end.stage ?? RideEndStage.ending,
        error: end.error,
      );
    }
    if (end.isEnding) {
      return RideEndProgress(stage: end.stage ?? RideEndStage.ending);
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

/// Runs End Ride for this rider: their record frozen and saved, the summary
/// written, the group told. The widget only shows [RideEndState].
class RideEndController extends Notifier<RideEndState> {
  RideEndController(this._code);

  final String _code;

  /// The upload queue this ride was put on while it saves.
  PendingRideUploadsController? _uploads;

  @override
  RideEndState build() {
    // If this screen goes before the ride is saved (the app closed, the
    // rider left), the queued upload is handed to the background worker.
    ref.onDispose(() => _uploads?.release(_code));
    return const RideEndState();
  }

  /// Waits between tries while saving, growing to [_maxRetryDelay].
  static const Duration _firstRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(seconds: 15);

  /// How long the name suggestion may take before the fallback is used.
  static const Duration _nameTimeout = Duration(seconds: 8);

  /// Ends this rider's own ride. Everyone else carries on.
  ///
  /// The same pipeline runs however the ride ended (End Ride, the auto-end
  /// countdown, solo or group): the ride is finalised, its record and route
  /// saved, the summary written, the ride saved to history and read back.
  /// Saving is retried until it succeeds ("Saving ride..."), so a finished
  /// ride is never lost. Only then is [RideEndState.completed] set, which
  /// shows Ride Complete and moves on to the results.
  Future<void> endRide({RideEndTrigger trigger = RideEndTrigger.manual}) async {
    if (state.isEnding || state.completed) return;
    final uid = ref.read(authStateChangesProvider).value?.uid;
    if (uid == null) return;
    final chosen = state.trigger ?? trigger;
    void stage(RideEndStage stage) {
      if (!ref.mounted) return;
      state = RideEndState(
        isEnding: true,
        stage: stage,
        errorId: state.errorId,
        trigger: chosen,
      );
    }

    final map = ref.read(rideMapControllerProvider(_code).notifier);
    // 1. Finalise: a last fix, the record frozen, location sharing stopped.
    stage(RideEndStage.ending);
    await map.finishMyRide();
    if (!ref.mounted) return;

    // Named from the last GPS position before the ride ended, the same for
    // a manual and an automatic end. Editable on the results.
    final name = await ref
        .read(rideNamingServiceProvider)
        .suggest(start: map.firstPoint, end: map.lastPoint)
        .timeout(_nameTimeout, onTimeout: () => RideNames.fallback);
    if (!ref.mounted) return;

    // 2–10. Save everything, and keep trying until it is saved. The ride is
    // queued first, so if it cannot reach the cloud now (offline, or the app
    // is closed meanwhile) it is uploaded as soon as the connection returns.
    stage(RideEndStage.savingRiders);
    final uploads = ref.read(pendingRideUploadsProvider.notifier);
    _uploads = uploads;
    await uploads.enqueue(uid: uid, code: _code, name: name);
    if (!ref.mounted) return;
    var delay = _firstRetryDelay;
    while (true) {
      final recordSaved = await map.confirmFinalRecord();
      if (!ref.mounted) return;
      if (recordSaved) {
        stage(RideEndStage.generatingSummary);
        final result = await ref
            .read(rideCompletionServiceProvider)
            .publishMyFinish(code: _code, uid: uid, name: name);
        if (!ref.mounted) return;
        if (result is Success) {
          await uploads.complete(uid: uid, code: _code);
          if (!ref.mounted) return;
          break;
        }
        debugPrint('[ride] Saving the ride failed, retrying: $result');
        stage(RideEndStage.savingRiders);
      }
      await Future<void>.delayed(delay);
      if (!ref.mounted) return;
      delay = delay * 2 > _maxRetryDelay ? _maxRetryDelay : delay * 2;
    }

    // The ride is safe. Its highlights (the history card's score and
    // achievements) and the device's copy of the history are brought up to
    // date too, briefly; the history screens fill in anything left later.
    await _saveExtras(uid).timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    if (!ref.mounted) return;
    unawaited(map.stopTracking());
    state = RideEndState(
      stage: RideEndStage.complete,
      completed: true,
      errorId: state.errorId,
      trigger: chosen,
    );
  }

  Future<void> _saveExtras(String uid) async {
    try {
      final repository = ref.read(rideHistoryRepositoryProvider);
      final earlier = await repository.cached(uid);
      final recap = await ref
          .read(rideRecapServiceProvider)
          .load(
            _code,
            myUid: uid,
            previousRides: pastRidesFrom([
              for (final e in earlier)
                if (e.code != _code) e,
            ]),
          );
      if (recap != null) {
        await repository.saveHighlights(
          uid: uid,
          code: _code,
          highlights: recap.highlights,
        );
      }
      if (ref.mounted) {
        await ref.read(rideHistoryProvider.notifier).refresh();
      }
    } on Object catch (e) {
      debugPrint('[ride] Saving the ride extras skipped: $e');
    }
  }

  /// Hides a failed ending.
  void dismissError() {
    if (state.isEnding) return;
    state = RideEndState(errorId: state.errorId, trigger: state.trigger);
  }
}
