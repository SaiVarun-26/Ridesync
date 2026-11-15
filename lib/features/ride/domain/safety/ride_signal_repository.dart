import '../../../../core/errors/result.dart';
import '../geo_point.dart';
import 'ride_signal.dart';

/// Contract for the group's live safety signals in one room.
abstract interface class RideSignalRepository {
  /// Every rider's latest signal, by uid, live.
  Stream<Map<String, RideSignal>> watch({required String code});

  /// Sends [kind] from this rider, replacing their previous signal.
  Future<Result<void>> send({
    required String code,
    required RideSignalKind kind,
    GeoPoint? at,
  });

  /// Removes this rider's signal.
  Future<Result<void>> clear({required String code});
}
