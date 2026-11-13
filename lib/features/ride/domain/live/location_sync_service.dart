import 'dart:async';
import 'dart:developer' as developer;

import '../../../../core/errors/result.dart';
import '../live_location_repository.dart';
import '../location_fix.dart';
import '../location_repository.dart';

/// Streams this rider's GPS fixes and shares them with the room.
///
/// Battery and data are kept low by design:
/// - the GPS only reports after about [distanceFilterMeters] of movement, so
///   a stopped rider costs almost nothing;
/// - uploads are throttled to one per [minPublishInterval], always sending the
///   newest fix (a trailing publish catches the last movement);
/// - nothing is sent while stationary; presence, not a heartbeat, tells the
///   group the rider is still there.
///
/// On every reconnect it re-registers removal of this rider's position on
/// disconnect (the server forgets that after it fires) and re-publishes the
/// latest fix.
class LocationSyncService {
  LocationSyncService({
    required LocationRepository location,
    required LiveLocationRepository liveLocations,
    required Stream<bool> connection,
    required String roomCode,
    this.minPublishInterval = const Duration(seconds: 1),
  }) : _location = location,
       _live = liveLocations,
       _connection = connection,
       _roomCode = roomCode;

  /// Movement needed before the GPS reports a new fix.
  static const int distanceFilterMeters = 5;

  /// Pause before re-subscribing after the location stream fails.
  static const Duration _restartDelay = Duration(seconds: 3);

  final Duration minPublishInterval;

  final LocationRepository _location;
  final LiveLocationRepository _live;
  final Stream<bool> _connection;
  final String _roomCode;

  final StreamController<LocationFix> _fixes =
      StreamController<LocationFix>.broadcast();
  StreamSubscription<LocationFix>? _fixSub;
  StreamSubscription<bool>? _connectionSub;
  Timer? _pendingPublish;
  Timer? _restart;
  LocationFix? _latest;
  DateTime? _lastPublishedAt;
  bool _started = false;
  bool _stopped = false;

  /// Every fix from this device, for the local map. Not throttled.
  Stream<LocationFix> get fixes => _fixes.stream;

  /// Starts GPS updates and sharing. Calling it again has no effect.
  void start() {
    if (_started || _stopped) return;
    _started = true;
    _connectionSub = _connection.listen((connected) {
      if (connected) unawaited(_onConnected());
    });
    _subscribeToFixes();
  }

  /// Stops GPS updates and withdraws this rider's shared position.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _pendingPublish?.cancel();
    _restart?.cancel();
    await _fixSub?.cancel();
    await _connectionSub?.cancel();
    await _fixes.close();
    await _live.clear(code: _roomCode);
  }

  void _subscribeToFixes() {
    _fixSub = _location
        .watchFixes(distanceFilterMeters: distanceFilterMeters)
        .listen(
          _onFix,
          onError: (Object error, StackTrace stack) {
            developer.log(
              'Location stream failed; restarting.',
              name: 'LocationSyncService',
              error: error,
              stackTrace: stack,
            );
            _scheduleRestart();
          },
          onDone: _scheduleRestart,
        );
  }

  void _scheduleRestart() {
    if (_stopped || (_restart?.isActive ?? false)) return;
    _restart = Timer(_restartDelay, () async {
      await _fixSub?.cancel();
      if (!_stopped) _subscribeToFixes();
    });
  }

  void _onFix(LocationFix fix) {
    if (_stopped) return;
    _latest = fix;
    _fixes.add(fix);
    _schedulePublish();
  }

  void _schedulePublish() {
    if (_stopped || _pendingPublish != null) return;
    final last = _lastPublishedAt;
    final wait = last == null
        ? Duration.zero
        : minPublishInterval - DateTime.now().difference(last);
    if (wait <= Duration.zero) {
      unawaited(_publishLatest());
    } else {
      _pendingPublish = Timer(wait, () {
        _pendingPublish = null;
        unawaited(_publishLatest());
      });
    }
  }

  Future<void> _publishLatest() async {
    final fix = _latest;
    if (fix == null || _stopped) return;
    _lastPublishedAt = DateTime.now();
    final result = await _live.publish(code: _roomCode, fix: fix);
    if (result case Failed(:final failure)) {
      developer.log(
        'Publish failed: ${failure.message}',
        name: 'LocationSyncService',
      );
    }
  }

  Future<void> _onConnected() async {
    if (_stopped) return;
    await _live.removeOnDisconnect(code: _roomCode);
    if (_latest != null) _schedulePublish();
  }
}
