import 'geo_point.dart';
import 'location_fix.dart';

/// Whether the app may read the device location.
enum LocationAccess {
  /// Location may be read while the app is in use.
  granted,

  /// Not granted yet; asking again can show the system prompt.
  denied,

  /// Denied in a way only the system Settings app can undo.
  deniedForever,
}

/// Contract for device location: permission, service state, and fixes.
///
/// Implemented in the data layer over a platform plugin and injected via
/// Riverpod, so initialization logic stays SDK-free and testable.
abstract interface class LocationRepository {
  /// The current permission state, without prompting.
  Future<LocationAccess> checkPermission();

  /// Asks the user for location access (when the platform allows a prompt)
  /// and returns the resulting state.
  Future<LocationAccess> requestPermission();

  /// Whether the device's location service (GPS) is switched on.
  Future<bool> isServiceEnabled();

  /// Emits whether the location service is on, starting with the current
  /// state and then on every change.
  Stream<bool> watchServiceEnabled();

  /// A single fresh location fix, or `null` if none arrives within [timeout]
  /// or location is unavailable.
  Future<GeoPoint?> currentPosition({required Duration timeout});

  /// Continuous high-accuracy fixes while riding. A new fix is delivered only
  /// after the device moves about [distanceFilterMeters], which keeps GPS and
  /// network use low. Cancel the subscription to stop location updates.
  Stream<LocationFix> watchFixes({required int distanceFilterMeters});

  /// Opens this app's page in the system Settings app. Returns whether it
  /// opened.
  Future<bool> openAppSettings();
}
