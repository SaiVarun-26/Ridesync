import '../../../core/errors/result.dart';
import 'location_fix.dart';
import 'rider_location.dart';

/// Contract for sharing rider positions during a live ride.
///
/// Positions are high-frequency live data, so they are kept apart from the
/// room node: listening to positions never re-sends the whole room, and room
/// listeners are not woken by every GPS update.
abstract interface class LiveLocationRepository {
  /// Every change to the room's shared positions, one rider at a time. Each
  /// existing position is first reported as a [RiderLocationUpdated].
  Stream<RiderLocationChange> watchChanges({required String code});

  /// Shares this rider's [fix] with the room.
  Future<Result<void>> publish({
    required String code,
    required LocationFix fix,
  });

  /// Registers server-side removal of this rider's position if the client
  /// disconnects, so a dropped rider disappears for everyone.
  Future<Result<void>> removeOnDisconnect({required String code});

  /// Withdraws this rider's position, e.g. when leaving the ride.
  Future<Result<void>> clear({required String code});
}
