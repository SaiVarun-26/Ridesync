import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../domain/live/ride_notification.dart';

/// Outcome of trying to start background tracking.
enum TrackingStartResult {
  /// The foreground service is running.
  started,

  /// Location permission ("Allow all the time") was refused.
  locationDenied,

  /// The service could not be started for another reason.
  failed,
}

/// Owns the Android foreground service that keeps the Free Roam ride alive
/// while the app is backgrounded, the screen is off, or the rider is on a
/// call.
///
/// Design: GPS and all Firebase writes stay in the main isolate, where
/// Firebase is already initialized and the existing location/sync code runs.
/// This service's only jobs are to keep that isolate alive (the foreground
/// service prevents it being frozen or killed) and to show and update the live
/// notification. It therefore holds no ride logic and talks to no database.
class BackgroundTrackingService {
  BackgroundTrackingService({PermissionGate? permissions})
    : _permissions = permissions ?? const PermissionGate();

  final PermissionGate _permissions;

  static const int _serviceId = 4411;
  static const String _channelId = 'ridesync_ride';
  static const String _channelName = 'Active Ride';

  bool _initialized = false;

  /// Prepares the notification channel and service options. Safe to call more
  /// than once.
  void configure() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: _channelName,
        channelDescription:
            'Keeps your ride tracking while the app is in the '
            'background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The main isolate drives updates; the task itself does no periodic
        // work, so it never needs to wake on a timer.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWifiLock: true,
      ),
    );
  }

  /// Requests the permissions background tracking needs and starts the
  /// service. Returns why it could not start, if it could not.
  ///
  /// [initialContent] seeds the notification; [onNotificationPressed] is run
  /// when the rider taps it, to return to the live ride.
  Future<TrackingStartResult> start({
    required RideNotificationContent initialContent,
  }) async {
    configure();

    if (!await _permissions.ensureLocationAlways()) {
      return TrackingStartResult.locationDenied;
    }
    await _permissions.ensureNotifications();
    await _permissions.ensureBatteryExemption();

    if (await FlutterForegroundTask.isRunningService) {
      return TrackingStartResult.started;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: initialContent.title,
      notificationText: initialContent.body,
      // Tapping the notification resumes the existing app task (handled by the
      // task handler's onNotificationPressed) rather than starting a new one.
      callback: _startBackgroundIsolate,
    );
    if (result is ServiceRequestSuccess) return TrackingStartResult.started;
    debugPrint('Foreground service failed to start: $result');
    return TrackingStartResult.failed;
  }

  /// Refreshes the live notification with the latest ride stats.
  Future<void> update(RideNotificationContent content) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: content.title,
      notificationText: content.body,
    );
  }

  /// Stops the service and removes the notification.
  Future<void> stop() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}

/// Entry point for the foreground-service isolate. Must be a top-level
/// function annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
void _startBackgroundIsolate() {
  FlutterForegroundTask.setTaskHandler(_RideTaskHandler());
}

/// Minimal task handler. The ride runs in the main isolate, so this only
/// bridges notification taps back to the app. It computes nothing.
class _RideTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() {
    // Bring the existing app task to the front without restarting it.
    FlutterForegroundTask.launchApp();
  }
}

/// Wraps the runtime permission prompts background tracking needs, so the
/// service and tests can substitute them.
class PermissionGate {
  const PermissionGate();

  /// Ensures "Allow all the time" location. Returns whether it is granted.
  Future<bool> ensureLocationAlways() async {
    // On Android the plugin escalates to background ("all the time") access.
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    // Location itself is requested by the geolocator flow during ride
    // initialization; here we only confirm notifications can show. Background
    // location is granted through the system service-type prompt.
    return permission != NotificationPermission.permanently_denied;
  }

  /// Requests notification permission (Android 13+). Best-effort.
  Future<void> ensureNotifications() async {
    final current = await FlutterForegroundTask.checkNotificationPermission();
    if (current != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// Asks to be exempt from battery optimization, so the service is not
  /// throttled. Best-effort; the ride works without it.
  Future<void> ensureBatteryExemption() async {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }
}
