import 'dart:async';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../room/domain/room.dart';
import '../../../room/domain/room_repository.dart';
import '../stats/ride_stats.dart';
import '../stats/ride_stats_repository.dart';
import '../summary/ride_summary.dart';
import '../summary/ride_summary_builder.dart';
import '../summary/ride_summary_repository.dart';
import 'ride_end_stage.dart';

/// Ends a ride from the host's side.
///
/// The sequence:
/// 1. The room moves to `ending`. Every rider's phone reacts by saving a final
///    record (stats, route, finish time) and marking itself finished.
/// 2. The host waits until every rider who is online has finished, or
///    [finishTimeout] passes, whichever comes first. A rider who is offline or
///    slow does not hold the group up: their last saved stats are used.
/// 3. The host builds the summary from everyone's stats and writes it.
/// 4. The room moves to `ended`, which takes every rider to the results.
///
/// The steps are safe to repeat: if a step fails, pressing End Ride again
/// resumes from where it stopped. The room only becomes `ended` after the
/// summary exists. Holds no UI and no Firebase types.
class RideCompletionService {
  RideCompletionService({
    required RoomRepository rooms,
    required RideStatsRepository stats,
    required RideSummaryRepository summaries,
    int Function()? nowMs,
    this.finishTimeout = const Duration(seconds: 5),
  }) : _rooms = rooms,
       _stats = stats,
       _summaries = summaries,
       _nowMs = nowMs ?? _systemNowMs;

  /// How long to wait for riders to confirm their final stats.
  final Duration finishTimeout;

  final RoomRepository _rooms;
  final RideStatsRepository _stats;
  final RideSummaryRepository _summaries;
  final int Function() _nowMs;

  /// How long to wait for a room snapshot before treating the network as down.
  static const Duration _roomTimeout = Duration(seconds: 5);

  static int _systemNowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Ends the ride in room [code] and returns the summary that was written.
  ///
  /// [onStage] is told each time the work moves on, so the UI can show
  /// progress.
  Future<Result<RideSummary>> endRide({
    required String code,
    void Function(RideEndStage stage)? onStage,
  }) async {
    onStage?.call(RideEndStage.ending);
    final begun = await _rooms.beginEndingRide(code: code);
    if (begun case Failed(:final failure)) return Failed(failure);
    onStage?.call(RideEndStage.savingRiders);

    final room = await _currentRoom(code);
    if (room == null) {
      return const Failed(
        NetworkFailure(message: 'Could not reach the ride. Try again.'),
      );
    }

    // Offline riders cannot respond, so waiting on them would only burn the
    // timeout.
    final expected = [
      for (final member in room.members)
        if (member.online) member.uid,
    ];
    final stats = await _collectFinalStats(code, expected);
    onStage?.call(RideEndStage.generatingSummary);

    // Re-read the room so names and colors are as they are now.
    final latest = await _currentRoom(code) ?? room;
    final summary = RideSummaryBuilder.build(
      room: latest,
      stats: stats,
      endedAtMs: _nowMs(),
    );

    final saved = await _summaries.save(code: code, summary: summary);
    if (saved case Failed(:final failure)) return Failed(failure);

    final completed = await _rooms.completeRide(code: code);
    if (completed case Failed(:final failure)) return Failed(failure);

    onStage?.call(RideEndStage.complete);
    return Success(summary);
  }

  /// Every rider's stats, once all [expected] riders are finished or the
  /// timeout passes.
  Future<Map<String, RideStats>> _collectFinalStats(
    String code,
    List<String> expected,
  ) async {
    var latest = <String, RideStats>{};
    final allFinished = Completer<void>();

    bool everyoneFinished(Map<String, RideStats> stats) =>
        expected.every((uid) => stats[uid]?.isFinished ?? false);

    if (expected.isEmpty) return latest;

    final subscription = _stats
        .watchAll(code: code)
        .listen(
          (stats) {
            latest = stats;
            if (everyoneFinished(stats) && !allFinished.isCompleted) {
              allFinished.complete();
            }
          },
          onError: (Object _) {
            if (!allFinished.isCompleted) allFinished.complete();
          },
        );
    await allFinished.future.timeout(finishTimeout, onTimeout: () {});
    // Not awaited: a stream that is slow to cancel must never hold up ending
    // the ride once the wait is over.
    unawaited(subscription.cancel());
    return latest;
  }

  Future<Room?> _currentRoom(String code) async {
    try {
      return await _rooms.watchRoom(code: code).first.timeout(_roomTimeout);
    } on TimeoutException {
      return null;
    } on StateError {
      // The stream closed without a value.
      return null;
    }
  }
}
