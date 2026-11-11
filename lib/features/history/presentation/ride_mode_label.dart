import '../../room/domain/ride_mode.dart';

/// Rider-facing names for ride modes.
extension RideModeLabel on RideMode {
  String get label => switch (this) {
    RideMode.free => 'Free Roam',
    RideMode.guided => 'Guided',
  };
}
