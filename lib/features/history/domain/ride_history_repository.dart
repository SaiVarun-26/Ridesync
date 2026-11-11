import '../../../core/errors/result.dart';
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

  /// Adds the finished ride [code] to [uid]'s history. Does nothing if it is
  /// already there or if [uid] was not part of the ride.
  Future<Result<void>> record({required String uid, required String code});
}
