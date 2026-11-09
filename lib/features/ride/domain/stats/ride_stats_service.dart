import 'dart:async';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../geo_point.dart';
import '../location_fix.dart';
import 'recorded_route.dart';
import 'ride_stats.dart';
import 'ride_stats_repository.dart';
import 'ride_stats_tracker.dart';

/// Records this rider's ride and keeps it safe.
///
/// - **Continuous:** every GPS fix updates the statistics and the recorded
///   route immediately; changes are saved every [saveInterval] (the route
///   less often), never only at the end. A crash loses seconds, not the ride.
/// - **Resumable:** on [start] it restores whatever was saved for this room and
///   carries on from it. Rejoining after a disconnect, background kill, or
///   crash continues the same ride; nothing is reset.
/// - **Safe:** nothing is saved until the previous record has been loaded
///   successfully, so a failed load can never overwrite real progress with an
///   empty ride. Fixes that arrive meanwhile are held and replayed in order.
///
/// Holds no UI and no Firebase types: storage goes through
/// [RideStatsRepository].
class RideStatsService {
  RideStatsService({
    required RideStatsRepository repository,
    required String roomCode,
    this.saveInterval = const Duration(seconds: 10),
  })  : _repository = repository,
        _roomCode = roomCode;

  /// How often changed statistics are saved.
  final Duration saveInterval;

  final RideStatsRepository _repository;
  final String _roomCode;

  final RideStatsTracker _tracker = RideStatsTracker();
  final RecordedRoute _route = RecordedRoute();
  final StreamController<RideStats> _updates =
      StreamController<RideStats>.broadcast();
  final List<LocationFix> _held = [];

  Timer? _timer;
  Future<void> _saveChain = Future<void>.value();
  int _saving = 0;
  int _ticks = 0;
  int _statsVersion = 0;
  int _savedStatsVersion = 0;
  int _savedRouteVersion = 0;

  /// The stats version whose last point the saved route already ends at.
  int _routeEndVersion = 0;
  final Completer<bool> _readyCompleter = Completer<bool>();
  bool _started = false;
  bool _ready = false;
  bool _closed = false;
  bool _finished = false;

  /// The route is saved on every this-many'th save tick (it is much larger
  /// than the statistics).
  static const int _routeEveryTicks = 3;

  /// Fixes held while the saved record loads; the oldest are dropped past
  /// this.
  static const int _maxHeld = 1500;

  static const Duration _restoreRetry = Duration(seconds: 3);
  static const Duration _restoreTimeout = Duration(seconds: 8);

  /// How long finishing waits for the saved ride to load, if it has not yet.
  static const Duration _finishReadyWait = Duration(seconds: 2);

  /// The statistics after every accepted fix.
  Stream<RideStats> get updates => _updates.stream;

  /// The statistics so far, or `null` before the first accepted fix.
  RideStats? get current => _tracker.stats;

  /// The whole-ride route recorded so far.
  List<GeoPoint> get route => _route.points;

  /// Restores any saved ride, then begins saving. Calling it again has no
  /// effect.
  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    await _restore();
    if (_closed) {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete(false);
      return;
    }

    _ready = true;
    // A ride restored as already finished stays frozen.
    if (_tracker.stats?.isFinished ?? false) _finished = true;
    for (final fix in _held) {
      _apply(fix);
    }
    _held.clear();
    if (!_finished) {
      _timer = Timer.periodic(saveInterval, (_) => _onTick());
    }
    _readyCompleter.complete(true);
  }

  /// Freezes the ride at [endedAtMs] and saves its final record: the whole
  /// route first, then the statistics marked finished. Returns the final
  /// statistics, or `null` if the saved ride never loaded (so nothing can be
  /// saved safely).
  ///
  /// The route is saved before the finished marker because the security rules
  /// lock a rider's record once it is marked finished. After this, new fixes
  /// are ignored. Calling it again returns the same final statistics.
  Future<RideStats?> finish({required int endedAtMs}) async {
    if (_closed) return _tracker.stats;
    if (_finished) return _tracker.stats;
    _finished = true;
    _timer?.cancel();

    final ready = await _readyCompleter.future.timeout(
      _finishReadyWait,
      onTimeout: () => false,
    );
    if (!ready) return null;

    // Let any save already in progress land first, so it cannot arrive after
    // the finished marker and be refused.
    await _saveChain;

    // A rider who never got a GPS fix still finishes, with an empty ride.
    final base = _tracker.stats ?? RideStats(startedAtMs: endedAtMs);
    final done = base.copyWith(endedAtMs: endedAtMs);
    _tracker.restore(done);
    _statsVersion++;
    if (!_updates.isClosed) _updates.add(done);

    // Both writes are issued back to back, route first; the database applies
    // a client's writes in the order they were sent.
    final results = await Future.wait([
      _repository.saveMyRoute(code: _roomCode, route: _routeWithEnd()),
      _repository.saveMine(code: _roomCode, stats: done),
    ]);
    if (results[0] is Success) {
      _savedRouteVersion = _route.version;
      _routeEndVersion = _statsVersion;
    }
    if (results[1] is Success) _savedStatsVersion = _statsVersion;
    return done;
  }

  /// Folds a GPS [fix] into the ride.
  void addFix(LocationFix fix) {
    if (_closed || _finished) return;
    if (!_ready) {
      _held.add(fix);
      if (_held.length > _maxHeld) _held.removeAt(0);
      return;
    }
    _apply(fix);
  }

  /// Saves everything that changed, waiting for any save already in progress.
  Future<void> flush() => _enqueueSave(includeRoute: true, isFinal: true);

  /// Stops recording and makes a final save.
  Future<void> dispose() async {
    if (_closed) return;
    _timer?.cancel();
    if (_ready) await flush();
    _closed = true;
    if (!_readyCompleter.isCompleted) _readyCompleter.complete(false);
    await _updates.close();
  }

  Future<void> _restore() async {
    while (!_closed) {
      final stats = await _repository
          .loadMine(code: _roomCode)
          .timeout(
            _restoreTimeout,
            onTimeout: () => const Failed<RideStats?>(NetworkFailure()),
          );
      final route = await _repository
          .loadMyRoute(code: _roomCode)
          .timeout(
            _restoreTimeout,
            onTimeout: () => const Failed<List<GeoPoint>>(NetworkFailure()),
          );

      if (stats is Success<RideStats?> && route is Success<List<GeoPoint>>) {
        final saved = stats.value;
        if (saved != null) _tracker.restore(saved);
        _route.restore(route.value);
        // What was just loaded is already saved.
        _savedRouteVersion = _route.version;
        _routeEndVersion = _statsVersion;
        return;
      }
      await Future<void>.delayed(_restoreRetry);
    }
  }

  void _apply(LocationFix fix) {
    if (!_tracker.add(fix)) return;
    _statsVersion++;
    _route.add(fix.point);
    final stats = _tracker.stats;
    if (stats != null && !_updates.isClosed) _updates.add(stats);
  }

  void _onTick() {
    _ticks++;
    // Offline saves wait on the server; do not pile more up behind them.
    if (_saving > 0) return;
    unawaited(_enqueueSave(includeRoute: _ticks % _routeEveryTicks == 0));
  }

  Future<void> _enqueueSave({
    required bool includeRoute,
    bool isFinal = false,
  }) {
    _saving++;
    return _saveChain = _saveChain
        .then((_) => _saveOnce(includeRoute: includeRoute, isFinal: isFinal))
        .whenComplete(() => _saving--);
  }

  Future<void> _saveOnce({
    required bool includeRoute,
    required bool isFinal,
  }) async {
    final stats = _tracker.stats;
    if (stats != null && _statsVersion != _savedStatsVersion) {
      final version = _statsVersion;
      final result = await _repository.saveMine(code: _roomCode, stats: stats);
      if (result is Success) _savedStatsVersion = version;
    }
    // The periodic save only rewrites the route when it gained points. The
    // final save also makes sure the route ends exactly where the rider did.
    final routeChanged = _route.version != _savedRouteVersion ||
        (isFinal && _routeEndVersion != _statsVersion);
    if (includeRoute && routeChanged) {
      final version = _route.version;
      final endVersion = _statsVersion;
      final result = await _repository.saveMyRoute(
        code: _roomCode,
        route: isFinal ? _routeWithEnd() : _route.points,
      );
      if (result is Success) {
        _savedRouteVersion = version;
        if (isFinal) _routeEndVersion = endVersion;
      }
    }
  }

  /// The recorded route plus the rider's true last position. On a very long
  /// ride the recorded route is thinned, so its final point can trail the
  /// rider by a little; this makes the saved route end exactly where they did.
  List<GeoPoint> _routeWithEnd() {
    final points = List<GeoPoint>.of(_route.points);
    final end = _tracker.stats?.lastPoint;
    if (end != null && (points.isEmpty || points.last != end)) points.add(end);
    return points;
  }
}
