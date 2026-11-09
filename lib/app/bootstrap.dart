import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_config.dart';
import '../core/firebase/firebase_initializer.dart';
import '../firebase_options.dart';
import 'app.dart';

/// Single entry point for app startup.
///
/// Runs inside a guarded zone so uncaught async errors are logged rather than
/// silently lost. Firebase is initialized here, before [runApp], so the SDK is
/// ready before any provider reads it.
Future<void> bootstrap() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Open the port the background location service uses to send messages
      // (e.g. notification taps) to the app isolate.
      FlutterForegroundTask.initCommunicationPort();

      // Initialize Firebase before building the app. The generated
      // DefaultFirebaseOptions come from FlutterFire; the RTDB URL is supplied
      // explicitly in case the generated options omit it.
      // An empty databaseUrl is treated as "not set" by the initializer, so
      // the raw config value can be passed directly.
      await const FirebaseInitializer(
        databaseUrl: FirebaseConfig.databaseUrl,
      ).initialize(DefaultFirebaseOptions.currentPlatform);

      // Lock to portrait and enforce the edge-to-edge dark system UI that the
      // night-map aesthetic depends on.
      await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp],
      );
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF050505),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };

      runApp(const ProviderScope(child: RideSyncApp()));
    },
    (error, stack) {
      debugPrint('Uncaught zone error: $error\n$stack');
    },
  );
}
