import 'package:flutter/foundation.dart';

/// Non-secret, environment-level Firebase configuration that is not part of the
/// generated `firebase_options.dart`.
///
/// The Realtime Database URL lives here because FlutterFire sometimes omits it
/// from the generated options. Supplying it explicitly makes the RTDB instance
/// resolve deterministically instead of being inferred at runtime. This value
/// is project configuration, not a credential.
@immutable
abstract final class FirebaseConfig {
  /// The Realtime Database instance URL, e.g.
  /// `https://<project-id>-default-rtdb.<region>.firebasedatabase.app`.
  ///
  /// Resolved at compile time from the `RIDESYNC_RTDB_URL` dart-define, falling
  /// back to [_defaultDatabaseUrl]. Supply the real URL either via
  /// `--dart-define=RIDESYNC_RTDB_URL=...` or by setting [_defaultDatabaseUrl]
  /// to the value from the Firebase console (Realtime Database page). Leave
  /// empty only if the generated options already carry a `databaseURL` for the
  /// current platform; an empty value is treated as "not set".
  static const String databaseUrl = bool.hasEnvironment('RIDESYNC_RTDB_URL')
      ? String.fromEnvironment('RIDESYNC_RTDB_URL')
      : _defaultDatabaseUrl;

  /// Compile-time default used when no dart-define is supplied.
  ///
  /// This is the `ridesync-dff42` Realtime Database instance in the
  /// `asia-southeast1` region. It is supplied here because the generated
  /// `firebase_options.dart` does not carry a `databaseURL`, so the SDK would
  /// otherwise be unable to resolve the regional instance. This is project
  /// configuration, not a secret.
  static const String _defaultDatabaseUrl =
      'https://ridesync-dff42-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Whether a usable database URL has been configured.
  static bool get hasDatabaseUrl => databaseUrl.isNotEmpty;

  const FirebaseConfig._();
}
