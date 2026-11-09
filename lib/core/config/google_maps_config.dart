import 'package:flutter/foundation.dart';

/// Google Maps Platform settings that ship inside the app.
///
/// Supplied at build time with
/// `--dart-define-from-file=config/google_maps.json` (git-ignored; see
/// `config/google_maps.example.json`), so keys never live in source control.
/// The Routes API key is not here: it exists only on the server, in Secret
/// Manager.
@immutable
abstract final class GoogleMapsConfig {
  /// Key for the Places API (New), used for destination search.
  static const String placesApiKey =
      String.fromEnvironment('RIDESYNC_PLACES_API_KEY');

  /// SHA-1 of the certificate this build is signed with (hex, colons
  /// optional). Sent with Places requests so a key restricted to this Android
  /// app accepts them. Debug and release builds are signed differently.
  static const String androidCertSha1 =
      String.fromEnvironment('RIDESYNC_ANDROID_CERT_SHA1');

  /// Android package name, sent alongside [androidCertSha1].
  static const String androidPackage = 'com.ridesync.ridesync';

  /// iOS bundle identifier, sent for keys restricted to the iOS app.
  static const String iosBundleId = 'com.ridesync.ridesync';

  const GoogleMapsConfig._();
}
