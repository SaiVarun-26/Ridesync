import '../../../core/errors/result.dart';
import 'recap_highlights.dart';
import 'ride_history_entry.dart';

/// Reads and records a rider's finished rides.
///
/// History is read on demand, one page at a time, never streamed. The most
/// recent page is also kept on the device so it can be shown offline.
abstract interface class RideHistoryRepository {
  /// The newest page last saved on this device for [uid]; empty if none.
  Future<List<RideHistoryEntry>> cached(String uid);

  /// Up to [limit] rides, newest first. With [after] set, continues with the
  /// rides older than that entry; otherwise starts from the newest.
  Future<Result<RideHistoryPage>> loadPage({
    required String uid,
    RideHistoryEntry? after,
    int limit = 20,
  });

  /// Builds the route preview for a ride saved without one, from the rider's
  /// recorded GPS route, and saves it so every device gets it. Returns the
  /// entry with its preview, or `null` when the ride has no recorded route.
  Future<RideHistoryEntry?> generatePreview({
    required String uid,
    required RideHistoryEntry entry,
  });

  /// Adds the finished ride [code] to [uid]'s history. Does nothing if it is
  /// already there or if [uid] was not part of the ride.
  Future<Result<void>> record({required String uid, required String code});

  /// [uid]'s best rides across their whole history: the [count] longest and
  /// the [count] with the highest top speed, without duplicates. Used for
  /// personal records, so they hold against every ride, not only the ones
  /// loaded on screen. Empty when they cannot be read; never throws.
  Future<List<RideHistoryEntry>> personalBests({
    required String uid,
    int count = 3,
  });

  /// Saves [highlights] onto [uid]'s history entry for ride [code], so every
  /// device can show them without working out the recap. Highlights are
  /// written once and never changed. Returns whether they were saved; never
  /// throws.
  Future<bool> saveHighlights({
    required String uid,
    required String code,
    required RecapHighlights highlights,
  });
}
