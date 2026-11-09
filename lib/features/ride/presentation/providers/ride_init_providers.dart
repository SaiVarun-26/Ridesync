import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../room/domain/ride_mode.dart';
import '../../../room/domain/room.dart';
import '../../../room/domain/room_status.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/asset_map_style_repository.dart';
import '../../data/geolocator_location_repository.dart';
import '../../domain/initialization/init_task.dart';
import '../../domain/initialization/ride_init_plan.dart';
import '../../domain/initialization/ride_initializer.dart';
import '../../domain/location_repository.dart';
import '../../domain/map_style_repository.dart';

/// Device location access, overridable in tests.
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return const GeolocatorLocationRepository();
});

/// Map style loading. Kept alive for the app's lifetime so the style loaded
/// during initialization is still cached when the map opens.
final mapStyleRepositoryProvider = Provider<MapStyleRepository>((ref) {
  return AssetMapStyleRepository();
});

/// Identifies one ride initialization: the room and the ride type, which
/// decides the plan.
typedef RideInitArgs = ({String code, RideMode mode});

/// The current rider's initialization for a room, auto-disposed when the
/// initialization screen closes.
final rideInitControllerProvider = NotifierProvider.autoDispose
    .family<RideInitController, RideInitState, RideInitArgs>(
  RideInitController.new,
);

/// What the initialization screen shows for the current rider.
class RideInitState {
  const RideInitState({required this.steps, this.isSlow = false});

  /// Every step of the plan, in order.
  final List<InitStepState> steps;

  /// Whether initialization has run longer than expected.
  final bool isSlow;

  /// Whether every step finished on this device.
  bool get isComplete => steps.isNotEmpty && steps.every((s) => s.isDone);

  /// The step waiting on a rider action, if any.
  InitStepState? get blockedStep {
    for (final step in steps) {
      if (step.phase == InitStepPhase.blocked) return step;
    }
    return null;
  }

  RideInitState copyWith({List<InitStepState>? steps, bool? isSlow}) =>
      RideInitState(steps: steps ?? this.steps, isSlow: isSlow ?? this.isSlow);
}

/// Runs this rider's initialization, reports completion to the room, and, on
/// the host's device, advances the whole group once every connected rider has
/// finished.
///
/// All decisions live here rather than in the widget: the screen only renders
/// [RideInitState] and forwards rider actions.
class RideInitController extends Notifier<RideInitState> {
  RideInitController(this._args);

  final RideInitArgs _args;
  late RideInitializer _initializer;
  bool _isReporting = false;
  bool _isAdvancing = false;

  /// After this long, the screen says "Still preparing…".
  static const Duration _slowThreshold = Duration(seconds: 20);

  /// Pause after the last rider finishes so every device shows its final
  /// checkmark before the group moves on.
  static const Duration _settleDelay = Duration(milliseconds: 700);

  /// Pause before retrying a failed database write.
  static const Duration _writeRetryDelay = Duration(seconds: 2);

  @override
  RideInitState build() {
    _initializer = RideInitializer(
      buildRideInitPlan(
        mode: _args.mode,
        roomCode: _args.code,
        rooms: ref.read(roomRepositoryProvider),
        auth: ref.read(authRepositoryProvider),
        location: ref.read(locationRepositoryProvider),
        mapStyles: ref.read(mapStyleRepositoryProvider),
      ),
    );

    final progress = _initializer.progress.listen(_onProgress);
    final slowTimer = Timer(_slowThreshold, () {
      if (ref.mounted && !state.isComplete) {
        state = state.copyWith(isSlow: true);
      }
    });
    ref.listen<AsyncValue<Room?>>(roomStreamProvider(_args.code), (_, next) {
      _syncInitializedFlag(next.value);
      _maybeAdvance(next.value);
    });
    ref.onDispose(() {
      slowTimer.cancel();
      unawaited(progress.cancel());
      unawaited(_initializer.dispose());
    });

    // Clear any flag left from an earlier run, so the group only counts this
    // device once it has really finished.
    unawaited(_writeInitialized(false));
    _initializer.start();
    return RideInitState(steps: _initializer.steps);
  }

  /// Handles the rider's tap on the blocked step's action.
  Future<void> resolveBlocker() async {
    final blocked = state.blockedStep;
    if (blocked == null) return;
    if (blocked.blocker == InitBlocker.locationPermissionDeniedForever) {
      // Only Settings can grant access now; the screen retries when the app
      // returns to the foreground.
      await ref.read(locationRepositoryProvider).openAppSettings();
      return;
    }
    _initializer.retry();
  }

  /// Re-runs a blocked step, e.g. after returning from Settings.
  void retry() => _initializer.retry();

  void _onProgress(List<InitStepState> steps) {
    if (!ref.mounted) return;
    state = state.copyWith(steps: steps);
    _syncInitializedFlag(ref.read(roomStreamProvider(_args.code)).value);
  }

  /// Keeps this rider's `initialized` flag true once this device is done.
  ///
  /// Besides the first report, this also repairs the flag when the server
  /// resets it: a brief connection drop runs the rider's disconnect handler,
  /// which clears the flag even though this device is still initialized.
  void _syncInitializedFlag(Room? room) {
    if (!state.isComplete || _isReporting || room == null) return;
    final myUid = ref.read(authRepositoryProvider).currentUser?.uid;
    final me = myUid == null ? null : room.memberByUid(myUid);
    if (me == null || me.isInitialized) return;
    _isReporting = true;
    unawaited(_reportComplete());
  }

  Future<void> _reportComplete() async {
    while (ref.mounted && !await _writeInitialized(true)) {
      await Future<void>.delayed(_writeRetryDelay);
    }
    _isReporting = false;
    if (ref.mounted) {
      _maybeAdvance(ref.read(roomStreamProvider(_args.code)).value);
    }
  }

  /// Writes this rider's initialized flag. Returns whether it succeeded.
  Future<bool> _writeInitialized(bool value) async {
    final result = await ref
        .read(roomRepositoryProvider)
        .setInitialized(code: _args.code, initialized: value);
    if (result case Failed(:final failure)) {
      debugPrint('Could not report initialized=$value: ${failure.message}');
      return false;
    }
    return true;
  }

  /// On the host's device: once this device and every connected rider have
  /// finished, move the room to riding. Every rider follows the status
  /// change.
  void _maybeAdvance(Room? room) {
    if (_isAdvancing || !state.isComplete || room == null) return;
    final myUid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (room.hostUid != myUid ||
        room.status != RoomStatus.initializing ||
        !room.everyoneConnectedInitialized) {
      return;
    }
    _isAdvancing = true;
    unawaited(_advance());
  }

  Future<void> _advance() async {
    await Future<void>.delayed(_settleDelay);
    if (!ref.mounted) return;
    final result = await ref
        .read(roomRepositoryProvider)
        .completeInitialization(code: _args.code);
    if (!ref.mounted) return;
    if (result case Failed(:final failure)) {
      debugPrint('Could not advance the ride: ${failure.message}');
      _isAdvancing = false;
      await Future<void>.delayed(_writeRetryDelay);
      if (ref.mounted) {
        _maybeAdvance(ref.read(roomStreamProvider(_args.code)).value);
      }
    }
  }
}
