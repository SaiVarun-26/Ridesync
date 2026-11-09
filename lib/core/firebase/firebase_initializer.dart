import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Centralized, modular Firebase bootstrap.
///
/// All Firebase infrastructure initialization lives here so [bootstrap] stays
/// readable and so future infrastructure (App Check, Crashlytics, emulator
/// wiring) can be added as discrete, append-only steps without restructuring.
///
/// [FirebaseOptions] is passed in rather than imported from the generated
/// `firebase_options.dart`. This keeps the initializer decoupled from generated
/// code (constructor-injection style), makes it unit-testable, and lets the app
/// compile before FlutterFire has generated the options. The composition root
/// ([bootstrap]) supplies `DefaultFirebaseOptions.currentPlatform` once that
/// file exists.
class FirebaseInitializer {
  const FirebaseInitializer({
    this.databaseUrl,
    this.useEmulators = false,
  });

  /// Explicit Realtime Database URL.
  ///
  /// FlutterFire usually embeds this in the generated options, but it is
  /// sometimes omitted. When provided, it is applied to the default
  /// [FirebaseDatabase] instance so RTDB resolves deterministically rather than
  /// guessing a URL at runtime.
  final String? databaseUrl;

  /// Reserved seam for local Firebase Emulator Suite wiring. Inert in V1; when
  /// enabled it will point Auth/Firestore/Database at localhost. Kept here so
  /// emulator support is a single-flag addition later, not a refactor.
  final bool useEmulators;

  /// Initializes Firebase and configures the backend services.
  ///
  /// Steps run in a deliberate order and each is isolated so additional
  /// concerns slot in without touching the others.
  Future<FirebaseApp> initialize(FirebaseOptions options) async {
    final app = await _initCore(options);

    // Future seam: App Check must be activated immediately after core init,
    // before any authenticated request. Intentionally not implemented in V1.
    // await _initAppCheck();

    _configureDatabase();

    // Future seam: Crashlytics / performance monitoring registration.
    // await _initCrashlytics();

    if (useEmulators) {
      // Future seam: wire Auth/Firestore/Database to the local emulators.
      _configureEmulators();
    }

    return app;
  }

  /// Step 1 — initialize Firebase Core with the platform options.
  Future<FirebaseApp> _initCore(FirebaseOptions options) {
    return Firebase.initializeApp(options: options);
  }

  /// Step 2 — configure the Realtime Database instance.
  ///
  /// Applies an explicit database URL when supplied and enables disk
  /// persistence so live state survives brief disconnects — appropriate for a
  /// group-ride app used on mobile networks.
  void _configureDatabase() {
    final db = FirebaseDatabase.instance;
    final url = databaseUrl;
    if (url != null && url.isNotEmpty) {
      db.databaseURL = url;
    }
    db.setPersistenceEnabled(true);
  }

  /// Reserved: point SDKs at the local emulator suite. Inert until enabled.
  void _configureEmulators() {
    // Intentionally empty in V1. Populated when local emulator testing is
    // introduced, guarded by [useEmulators].
    debugPrint('Firebase emulator mode requested but not configured in V1.');
  }
}
