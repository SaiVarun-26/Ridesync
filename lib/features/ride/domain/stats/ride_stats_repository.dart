import '../../../../core/errors/result.dart';
import '../geo_point.dart';
import 'ride_stats.dart';

/// Contract for saving and restoring the signed-in rider's ride record.
///
/// Statistics and the recorded route are saved continuously, not at the end,
/// so a crash, reconnect, or rejoin continues the same ride.
abstract interface class RideStatsRepository {
  /// This rider's saved statistics for room [code]; `null` if none exist yet.
  Future<Result<RideStats?>> loadMine({required String code});

  /// Saves this rider's [stats], replacing the previous copy.
  Future<Result<void>> saveMine({
    required String code,
    required RideStats stats,
  });

  /// This rider's saved whole-ride route; empty if none exists yet.
  Future<Result<List<GeoPoint>>> loadMyRoute({required String code});

  /// Saves this rider's whole-ride [route], replacing the previous copy.
  Future<Result<void>> saveMyRoute({
    required String code,
    required List<GeoPoint> route,
  });

  /// Every rider's statistics in room [code], by uid, live. Emits the full set
  /// each time any rider's record is added or changes.
  Stream<Map<String, RideStats>> watchAll({required String code});
}
