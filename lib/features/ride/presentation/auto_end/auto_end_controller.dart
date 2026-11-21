import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feedback/app_haptics.dart';
import '../../domain/live/stationary_detector.dart';
import '../../domain/location_fix.dart';
import '../providers/ride_completion_providers.dart';
import '../providers/ride_map_providers.dart';

/// When a ride may be ending by itself.
abstract final class AutoEndSettings {
  /// Genuinely still for this long, and the rider is asked whether the ride
  /// is over.
  static const Duration stationary = Duration(minutes: 5);

  /// How long the question waits for an answer before the ride ends.
  static const Duration countdown = Duration(seconds: 15);

  /// The rider must have ridden this far before a stop can mean the end, so
  /// waiting at the start never asks.
  static const double armedAfterMeters = 200;

  const AutoEndSettings._();
}

/// The auto-end question, while it is being asked.
@immutable
class AutoEndPrompt {
  const AutoEndPrompt({required this.id, required this.deadlineMs});

  /// Increases with every new question.
  final int id;

  /// When the ride ends if nobody answers (epoch millis).
  final int deadlineMs;
}

/// The clock auto end runs on (epoch millis); replaced in tests.
final autoEndClockProvider = Provider<int Function()>(
  (ref) => () => DateTime.now().millisecondsSinceEpoch,
);

final autoEndControllerProvider = NotifierProvider.autoDispose
    .family<AutoEndController, AutoEndPrompt?, String>(AutoEndController.new);

/// Watches this rider for a ride that has quietly come to an end.
///
/// After [AutoEndSettings.stationary] without meaningful movement it asks,
/// once, whether to end the ride, and ends it when
/// [AutoEndSettings.countdown] runs out unanswered. Moving again during the
/// countdown takes the question away by itself. Never asks while the ride is
/// paused, before the rider has really ridden, or once the ride is ending.
/// Only one question exists at a time.
class AutoEndController extends Notifier<AutoEndPrompt?> {
  AutoEndController(this._code);

  final String _code;
  final StationaryDetector _detector = StationaryDetector();
  Timer? _ticker;
  int _promptId = 0;

  static const Duration _tick = Duration(seconds: 1);

  @override
  AutoEndPrompt? build() {
    ref.listen<LocationFix?>(
      rideMapControllerProvider(_code).select((m) => m.myFix),
      (_, fix) {
        if (fix == null) return;
        final moved = _detector.add(fix);
        if (moved && state != null) _clear();
      },
      fireImmediately: true,
    );
    _ticker = Timer.periodic(_tick, (_) => _check());
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  int get _nowMs => ref.read(autoEndClockProvider)();

  void _check() {
    if (!ref.mounted) return;
    final now = _nowMs;
    final map = ref.read(rideMapControllerProvider(_code));
    final end = ref.read(rideEndControllerProvider(_code));
    if (end.isEnding || end.completed || map.isFinalSaved) {
      _ticker?.cancel();
      if (state != null) state = null;
      return;
    }
    if (map.isPaused) {
      // A pause is never the end; stillness starts counting when riding on.
      _detector.reset(now);
      if (state != null) state = null;
      return;
    }
    final prompt = state;
    if (prompt != null) {
      if (now >= prompt.deadlineMs) {
        state = null;
        // Should ending fail, the rider is not asked again straight away.
        _detector.reset(now);
        unawaited(
          ref
              .read(rideEndControllerProvider(_code).notifier)
              .endRide(trigger: RideEndTrigger.automatic),
        );
      }
      return;
    }
    final ridden = map.myStats?.distanceMeters ?? 0;
    if (ridden < AutoEndSettings.armedAfterMeters) return;
    if (_detector.stillFor(now) < AutoEndSettings.stationary) return;
    AppHaptics.milestone();
    state = AutoEndPrompt(
      id: ++_promptId,
      deadlineMs: now + AutoEndSettings.countdown.inMilliseconds,
    );
  }

  void _clear() {
    _detector.reset(_nowMs);
    state = null;
  }

  /// Continue Ride: the question goes, and stillness counts afresh.
  void keepRiding() {
    AppHaptics.selection();
    _clear();
  }

  /// Pause Ride: the ride pauses, so it is never ended while stopped.
  void pauseRide() {
    _clear();
    unawaited(ref.read(rideMapControllerProvider(_code).notifier).pause());
  }

  /// End Ride Now.
  void endNow() {
    _clear();
    unawaited(ref.read(rideEndControllerProvider(_code).notifier).endRide());
  }
}
