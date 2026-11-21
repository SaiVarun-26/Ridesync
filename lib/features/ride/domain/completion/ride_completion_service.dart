import 'dart:async';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../history/domain/ride_history_repository.dart';
import '../../../room/domain/rider_ride_state.dart';
import '../../../room/domain/room.dart';
import '../../../room/domain/room_repository.dart';
import '../stats/ride_stats.dart';
import '../stats/ride_stats_repository.dart';
import '../summary/ride_summary.dart';
import '../summary/ride_summary_builder.dart';
import '../summary/ride_summary_repository.dart';

/// Finishes one rider's ride. Every rider is equal: each ends only their own
/// ride, whenever they like, and the others carry on.
///
/// The same steps run however the ride ended (End Ride, the auto-end
/// countdown), once this rider's final record (statistics and route, which
/// the replay is drawn from) is saved:
/// 1. The ride summary is written again: a snapshot of the group as it
///    stands, with this rider's final figures. The results' cards, replay and
///    milestones are all built from it and the saved routes.
/// 2. The ride goes into this rider's history, under [publishMyFinish]'s
///    name, and is read back to make sure it is there.
/// 3. Only then is the rider marked finished, which tells the group ("Sai
///    completed the ride.") and moves this rider on to the results.
/// 4. If everyone else has finished too, this rider closes the room.
///
/// Safe to repeat: a retry redoes whatever did not land, and never makes a
/// second history entry. Holds no UI and no Firebase types.
class RideCompletionService {
  RideCompletionService({
    required RoomRepository rooms,
    required RideStatsRepository stats,
    required RideSummaryRepository summaries,
    required RideHistoryRepository history,
    int Function()? nowMs,
  }) : _rooms = rooms,
       _stats = stats,
       _summaries = summaries,
       _history = history,
       _nowMs = nowMs ?? _systemNowMs;

  final RoomRepository _rooms;
  final RideStatsRepository _stats;
  final RideSummaryRepository _summaries;
  final RideHistoryRepository _history;
  final int Function() _nowMs;

  /// How long to wait for a read or write before treating the network as
  /// down (and trying again later).
  static const Duration _timeout = Duration(seconds: 8);

  static int _systemNowMs() => DateTime.now().millisecondsSinceEpoch;

  static const Failure _notYet = NetworkFailure(
    message: 'Your ride is still being saved.',
  );

  /// Publishes [uid]'s finished ride in room [code], saved to their history
  /// as [name]. Succeeds only once the history entry is confirmed.
  Future<Result<RideSummary>> publishMyFinish({
    required String code,
    required String uid,
    required String name,
  }) async {
    final room = await _currentRoom(code);
    if (room == null) return const Failed(_notYet);
    final loaded = await _stats
        .loadAll(code: code)
        .timeout(_timeout, onTimeout: () => const Failed(_notYet));
    if (loaded case Failed(:final failure)) return Failed(failure);
    final stats = (loaded as Success<Map<String, RideStats>>).value;
    final mine = stats[uid];
    // The summary may only be written once this rider's record is final.
    if (mine == null || !mine.isFinished) return const Failed(_notYet);

    final previous = await _summaries
        .load(code: code)
        .timeout(_timeout, onTimeout: () => null);
    final summary = RideSummaryBuilder.build(
      room: room,
      stats: stats,
      endedAtMs: _latestEnd(stats) ?? mine.endedAtMs ?? _nowMs(),
      previous: previous,
    );
    final saved = await _summaries
        .save(code: code, summary: summary)
        .timeout(_timeout, onTimeout: () => const Failed(_notYet));
    if (saved case Failed(:final failure)) return Failed(failure);

    final recorded = await _history
        .record(uid: uid, code: code, name: name)
        .timeout(_timeout, onTimeout: () => const Failed(_notYet));
    if (recorded case Failed(:final failure)) return Failed(failure);
    final check = await _history.entry(uid: uid, code: code);
    if (check case Success(:final value) when value != null) {
      // Saved: only now is the rider told apart as finished.
    } else {
      return const Failed(_notYet);
    }

    // A write that cannot reach the server yet is kept on the device and
    // delivered later, so a slow network does not hold the rider up here.
    await _rooms
        .setMyRideState(code: code, state: RiderRideState.finished)
        .timeout(_timeout, onTimeout: () => const Success(null));

    // The last rider to finish closes the room. Someone who is offline but
    // has not finished keeps it open: their ride is still theirs to finish.
    final everyoneDone = room.members.every(
      (m) => m.uid == uid || m.hasFinished || (stats[m.uid]?.isFinished ?? false),
    );
    if (everyoneDone) {
      // This rider's ride is saved either way: a room that fails to close
      // only stays behind, and nothing waits on it.
      await _rooms
          .closeRide(code: code)
          .timeout(_timeout, onTimeout: () => const Success(null));
    }
    return Success(summary);
  }

  /// The latest finish among the riders who have finished.
  static int? _latestEnd(Map<String, RideStats> stats) {
    int? latest;
    for (final s in stats.values) {
      final end = s.endedAtMs;
      if (end != null && (latest == null || end > latest)) latest = end;
    }
    return latest;
  }

  Future<Room?> _currentRoom(String code) async {
    try {
      return await _rooms.watchRoom(code: code).first.timeout(_timeout);
    } on TimeoutException {
      return null;
    } on StateError {
      // The stream closed without a value.
      return null;
    }
  }
}
