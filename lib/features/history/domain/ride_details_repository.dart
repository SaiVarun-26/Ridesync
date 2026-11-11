import '../../../core/errors/result.dart';
import 'ride_details.dart';

/// Loads the full results of one finished ride.
abstract interface class RideDetailsRepository {
  /// The ride in room [code]. Read once from the network and saved on the
  /// device; if the network is unavailable the saved copy is returned instead
  /// (with [RideDetails.fromCache] set).
  Future<Result<RideDetails>> load(String code);
}
