import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../history/data/json_cache.dart';
import '../../ride/domain/geo_point.dart';
import '../domain/fuel_merge.dart';
import '../domain/fuel_station.dart';
import '../domain/fuel_station_source.dart';
import '../domain/fuel_tile.dart';

/// How the search for nearby fuel is going, for a one-line notice.
enum FuelSearchState {
  /// Nothing asked for yet.
  idle,

  /// Searching, and nothing is known nearby yet.
  searching,

  /// Stations are on the map.
  found,

  /// Every area around the rider has been searched and holds none.
  noneNearby,

  /// The services cannot be reached and nothing is known nearby.
  unavailable,
}

/// Keeps every fuel station within [radiusMeters] of the rider on the map,
/// anywhere, following them as they ride.
///
/// **Areas.** The ground is split into fixed areas ([FuelTile], ~9 km). The
/// areas touching the circle around the rider are the only ones searched or
/// shown, so a ride in Chennai never loads Bangalore. As the rider moves,
/// areas entering the circle are searched and areas left far behind are
/// dropped from memory.
///
/// **Completeness.** Each area is searched with Photon (nearest first, at
/// most 50 per answer). An answer that hits that limit before covering the
/// area means a dense area, so it is split into quarters and each searched
/// again, down to ~1 km squares, until every part has been covered. Overpass
/// (no limit) is also asked for each area in the background; its answers are
/// merged in, so a station either service knows is shown. Duplicates (the
/// same id, or the same pump mapped twice within a few metres) are merged
/// with [FuelMerge].
///
/// **Background.** Two workers, one per service, each send one request at a
/// time, nearest area first, spaced by [photonGap] and [overpassGap]. A
/// failure pauses that service, doubling the pause each time; nothing that
/// is already known leaves the map.
///
/// **Cache.** Each finished area is saved on the device. Coming back to an
/// area shows its saved stations at once; if they are older than
/// [refreshAfter] the area is searched again in the background and the fresh
/// answer replaces them.
///
/// Every step is logged with a `[fuel]` tag.
class FuelStationController extends ChangeNotifier {
  FuelStationController({
    required FuelStationProviders providers,
    JsonCache? cache,
    DateTime Function()? clock,
    this.radiusMeters = defaultRadiusMeters,
    this.refreshAfter = const Duration(hours: 6),
    this.photonGap = const Duration(milliseconds: 1100),
    this.overpassGap = const Duration(seconds: 4),
    this.useOverpass = true,
  }) : _providers = providers,
       _cache = cache,
       _clock = clock ?? DateTime.now;

  /// The default search radius: 15 km.
  static const double defaultRadiusMeters = 15000;

  final FuelStationProviders _providers;
  final JsonCache? _cache;
  final DateTime Function() _clock;

  /// How far around the rider stations are searched for and shown.
  final double radiusMeters;

  /// Saved areas older than this are searched again (in the background).
  final Duration refreshAfter;
  final Duration photonGap;
  final Duration overpassGap;
  final bool useOverpass;

  /// The most markers drawn at once, nearest first.
  static const int maxVisible = 400;

  /// The rider's position is looked at again only after moving this far.
  static const double _recheckMeters = 100;

  /// Areas further than the radius plus this are dropped from memory.
  static const double _keepExtraMeters = 10000;

  static const Duration _photonFirstBackoff = Duration(seconds: 5);
  static const Duration _photonMaxBackoff = Duration(minutes: 5);
  static const Duration _overpassFirstBackoff = Duration(minutes: 1);
  static const Duration _overpassMaxBackoff = Duration(minutes: 15);

  final Map<FuelTile, _Area> _areas = {};
  Set<FuelTile> _wanted = const {};
  GeoPoint? _rider;
  GeoPoint? _checkedAt;
  bool _disposed = false;

  final _Worker _photon = _Worker('photon');
  final _Worker _overpass = _Worker('overpass');

  bool _mergedDirty = true;
  List<FuelStation> _merged = const [];
  List<FuelStation> _visible = const [];
  FuelSearchState _state = FuelSearchState.idle;

  /// The stations within [radiusMeters] of the rider, nearest first, each
  /// once.
  List<FuelStation> get visible => _visible;

  FuelSearchState get state => _state;

  /// Requests sent so far, per service (for tests and diagnostics).
  int get photonRequests => _photon.requests;
  int get overpassRequests => _overpass.requests;

  /// When the stations around the rider were last brought up to date: the
  /// most recent finished search of an area around them, or `null` before
  /// any.
  DateTime? get lastUpdatedAt {
    DateTime? latest;
    for (final t in _wanted) {
      final at = _areas[t]?.fetchedAt;
      if (at != null && (latest == null || at.isAfter(latest))) latest = at;
    }
    return latest;
  }

  /// Whether every area around the rider has been fully searched.
  bool get isComplete =>
      _wanted.isNotEmpty && _wanted.every((t) => _areas[t]?.complete ?? false);

  /// Tells the controller where the rider is. Cheap to call on every fix.
  void updatePosition(GeoPoint rider) {
    if (_disposed) return;
    _rider = rider;
    final checked = _checkedAt;
    if (checked != null && checked.distanceMetersTo(rider) < _recheckMeters) {
      return;
    }
    _checkedAt = rider;
    final roots = FuelTile.rootsWithin(rider, radiusMeters).toSet();
    if (!setEquals(roots, _wanted)) {
      _wanted = roots;
      _mergedDirty = true;
      for (final root in roots) {
        _areas.putIfAbsent(root, () => _Area(root));
      }
      final before = _areas.length;
      _areas.removeWhere(
        (tile, _) =>
            !roots.contains(tile) &&
            tile.distanceMetersTo(rider) > radiusMeters + _keepExtraMeters,
      );
      _log(
        'Rider at ${_fmt(rider)}, radius ${_km(radiusMeters)}: '
        '${roots.length} areas around them'
        '${before > _areas.length ? ', ${before - _areas.length} far areas dropped' : ''}',
      );
    }
    _refreshVisible();
    unawaited(_readDisk());
    _pumpPhoton();
    _pumpOverpass();
  }

  // --- Device cache -----------------------------------------------------------

  Future<void> _readDisk() async {
    final pending = [
      for (final t in _wanted)
        if (_areas[t] case final a? when !a.diskChecked && !a.diskReading) a,
    ];
    for (final area in pending) {
      area.diskReading = true;
      final json = await _cache?.read(area.root.key);
      if (_disposed) return;
      area
        ..diskReading = false
        ..diskChecked = true;
      final saved = json == null ? null : _SavedArea.fromJson(json);
      if (saved != null && area.stations.isEmpty && area.building == null) {
        area
          ..stations = {for (final s in saved.stations) s.id: s}
          ..complete = saved.complete
          ..fetchedAt = saved.at;
        _mergedDirty = true;
        final age = _clock().difference(saved.at);
        _log(
          'Area ${area.root}: ${saved.stations.length} saved stations shown '
          '(${age.inMinutes} min old'
          '${age > refreshAfter ? ', refreshing in the background' : ''})',
        );
      }
    }
    if (pending.isNotEmpty) _refreshVisible();
    _pumpPhoton();
    _pumpOverpass();
  }

  Future<void> _save(_Area area) async {
    final at = area.fetchedAt;
    if (!area.complete || at == null) return;
    await _cache?.write(
      area.root.key,
      _SavedArea(
        stations: area.stations.values.toList(),
        complete: true,
        at: at,
      ).toJson(),
    );
  }

  // --- Photon: the complete, subdivided search ---------------------------------

  bool _needsPass(_Area a) =>
      a.diskChecked &&
      a.building == null &&
      !a.passStarted &&
      (!a.complete ||
          a.fetchedAt == null ||
          _clock().difference(a.fetchedAt!) > refreshAfter);

  /// The nearest square still to be searched, starting an area's search when
  /// it needs one.
  (_Area, FuelTile)? _nextPhoton() {
    final rider = _rider;
    if (rider == null) return null;
    (_Area, FuelTile)? best;
    var bestDistance = double.infinity;
    for (final t in _wanted) {
      final area = _areas[t];
      if (area == null) continue;
      final candidates = area.building != null
          ? area.pending
          : (_needsPass(area) ? [area.root] : const <FuelTile>[]);
      for (final tile in candidates) {
        final d = tile.distanceMetersTo(rider);
        if (d < bestDistance) {
          bestDistance = d;
          best = (area, tile);
        }
      }
    }
    return best;
  }

  void _pumpPhoton() {
    if (_disposed || _photon.busy) return;
    final next = _nextPhoton();
    if (next == null) return;
    final wait = _photon.waitFor(_clock(), photonGap);
    if (wait > Duration.zero) {
      _photon.wake(wait, _pumpPhoton);
      return;
    }
    final (area, tile) = next;
    if (area.building == null) {
      area
        ..building = {}
        ..pending = [area.root]
        ..passStarted = true
        ..tilesSearched = 0;
    }
    unawaited(_runPhoton(tile));
  }

  Future<void> _runPhoton(FuelTile tile) async {
    _photon.start(_clock());
    final radius = tile.halfDiagonalMeters;
    final result = await _providers.nearest(tile.center, radius);
    _photon.busy = false;
    if (_disposed) return;
    final area = _areas[tile.root];
    switch (result) {
      case FuelProviderFound(:final stations, :final capped):
        _photon.succeeded();
        final building = area?.building;
        if (area == null || building == null) break;
        area
          ..pending.remove(tile)
          ..tilesSearched += 1;
        FuelMerge.addAll(building, stations);
        final (added, dupes) = FuelMerge.addAll(area.stations, stations);
        final split = capped && tile.level < FuelTile.maxLevel;
        if (split) area.pending.addAll(tile.children);
        _log(
          'photon $tile r=${_km(radius)}: ${stations.length} stations in '
          '${result.elapsed.inMilliseconds} ms, +$added new, $dupes duplicates'
          '${split ? '; capped, splitting into 4' : ''}'
          '${capped && !split ? '; still capped at the finest level' : ''}',
        );
        if (added > 0) _mergedDirty = true;
        if (area.pending.isEmpty) _finishPass(area);
      case FuelProviderFailed(:final reason, :final throttled):
        final pause = _photon.failed(
          _clock(),
          throttled ? const Duration(seconds: 30) : _photonFirstBackoff,
          _photonMaxBackoff,
        );
        _log(
          'photon $tile failed after ${result.elapsed.inMilliseconds} ms '
          '($reason); retry ${_photon.failures} in ${pause.inSeconds} s',
        );
    }
    _refreshVisible();
    _pumpPhoton();
  }

  void _finishPass(_Area area) {
    final fresh = area.building!;
    // Overpass finds from this session stay, whatever order they came in.
    final (_, dupes) = FuelMerge.addAll(fresh, area.overpassStations);
    area
      ..stations = fresh
      ..building = null
      ..pending = []
      ..complete = true
      ..fetchedAt = _clock();
    _mergedDirty = true;
    _log(
      'Area ${area.root} complete: ${fresh.length} stations from '
      '${area.tilesSearched} photon searches'
      '${area.overpassStations.isEmpty ? '' : ' + overpass ($dupes shared)'}'
      '; ${_wanted.where((t) => _areas[t]?.complete ?? false).length}/'
      '${_wanted.length} areas done',
    );
    unawaited(_save(area));
  }

  // --- Overpass: the uncapped second opinion ----------------------------------

  void _pumpOverpass() {
    if (_disposed || !useOverpass || _overpass.busy) return;
    final rider = _rider;
    if (rider == null) return;
    _Area? best;
    var bestDistance = double.infinity;
    for (final t in _wanted) {
      final area = _areas[t];
      if (area == null || !area.diskChecked || area.overpassDone) continue;
      // A fresh saved area already holds both services' stations.
      if (area.complete && !area.passStarted) continue;
      final d = t.distanceMetersTo(rider);
      if (d < bestDistance) {
        bestDistance = d;
        best = area;
      }
    }
    if (best == null) return;
    final wait = _overpass.waitFor(_clock(), overpassGap);
    if (wait > Duration.zero) {
      _overpass.wake(wait, _pumpOverpass);
      return;
    }
    unawaited(_runOverpass(best.root));
  }

  Future<void> _runOverpass(FuelTile root) async {
    _overpass.start(_clock());
    final result = await _providers.inBox(
      south: root.south,
      west: root.west,
      north: root.north,
      east: root.east,
    );
    _overpass.busy = false;
    if (_disposed) return;
    final area = _areas[root];
    switch (result) {
      case FuelProviderFound(:final stations, :final provider):
        _overpass.succeeded();
        if (area == null) break;
        area
          ..overpassDone = true
          ..overpassStations = stations;
        final building = area.building;
        if (building != null) FuelMerge.addAll(building, stations);
        final (added, dupes) = FuelMerge.addAll(area.stations, stations);
        _log(
          '$provider $root: ${stations.length} stations in '
          '${result.elapsed.inMilliseconds} ms, +$added new, $dupes duplicates',
        );
        if (added > 0) {
          _mergedDirty = true;
          unawaited(_save(area));
        }
      case FuelProviderFailed(:final reason):
        final pause = _overpass.failed(
          _clock(),
          _overpassFirstBackoff,
          _overpassMaxBackoff,
        );
        _log(
          'overpass $root failed after ${result.elapsed.inMilliseconds} ms '
          '($reason); pausing ${pause.inSeconds} s (photon carries on)',
        );
    }
    _refreshVisible();
    _pumpOverpass();
  }

  // --- What is shown ----------------------------------------------------------

  void _refreshVisible() {
    final rider = _rider;
    if (rider == null) return;
    if (_mergedDirty) {
      _mergedDirty = false;
      final all = [
        for (final t in _wanted) ...?_areas[t]?.stations.values,
      ];
      final (unique, removed) = FuelMerge.dedupe(all);
      _merged = unique;
      if (removed > 0) {
        _log('Merged ${all.length} → ${unique.length} ($removed duplicates)');
      }
    }
    final near = <(double, FuelStation)>[
      for (final s in _merged)
        if (s.point.distanceMetersTo(rider) case final d when d <= radiusMeters)
          (d, s),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final next = [for (final (_, s) in near.take(maxVisible)) s];
    final changed = !listEquals(next, _visible);
    if (changed) {
      _visible = List.unmodifiable(next);
      _log(
        'Showing ${next.length} markers within ${_km(radiusMeters)} '
        '(${_merged.length} known around ${_fmt(rider)}'
        '${near.length > maxVisible ? ', nearest $maxVisible drawn' : ''})',
      );
    }
    final state = _visible.isNotEmpty
        ? FuelSearchState.found
        : isComplete
        ? FuelSearchState.noneNearby
        : _photon.failures > 0
        ? FuelSearchState.unavailable
        : FuelSearchState.searching;
    final stateChanged = state != _state;
    if (stateChanged && state == FuelSearchState.noneNearby) {
      _log('No fuel stations within ${_km(radiusMeters)} of ${_fmt(rider)}');
    }
    _state = state;
    if (changed || stateChanged) notifyListeners();
  }

  static void _log(String message) => debugPrint('[fuel] $message');
  static String _km(double m) => '${(m / 1000).toStringAsFixed(1)} km';
  static String _fmt(GeoPoint p) =>
      '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';

  @override
  void dispose() {
    _disposed = true;
    _photon.cancel();
    _overpass.cancel();
    super.dispose();
  }
}

/// One area's stations and how far its search has got.
class _Area {
  _Area(this.root);

  final FuelTile root;

  /// What is shown: saved or found so far, merged.
  Map<String, FuelStation> stations = {};

  /// The search under way, if any; replaces [stations] once complete.
  Map<String, FuelStation>? building;
  List<FuelTile> pending = [];
  int tilesSearched = 0;

  /// Whether a search was started this session.
  bool passStarted = false;
  bool complete = false;
  DateTime? fetchedAt;

  bool diskChecked = false;
  bool diskReading = false;

  bool overpassDone = false;
  List<FuelStation> overpassStations = const [];
}

/// One service's request pacing: one at a time, a gap between requests, a
/// growing pause after failures.
class _Worker {
  _Worker(this.name);

  final String name;
  bool busy = false;
  int requests = 0;
  int failures = 0;
  DateTime? _last;
  DateTime? _pausedUntil;
  Duration _backoff = Duration.zero;
  Timer? _timer;

  void start(DateTime now) {
    busy = true;
    requests++;
    _last = now;
  }

  void succeeded() {
    failures = 0;
    _backoff = Duration.zero;
    _pausedUntil = null;
  }

  /// Pauses after a failure; returns for how long.
  Duration failed(DateTime now, Duration first, Duration max) {
    failures++;
    _backoff = _backoff == Duration.zero
        ? first
        : Duration(
            milliseconds: math.min(
              _backoff.inMilliseconds * 2,
              max.inMilliseconds,
            ),
          );
    _pausedUntil = now.add(_backoff);
    return _backoff;
  }

  /// How long until the next request may go.
  Duration waitFor(DateTime now, Duration gap) {
    var wait = Duration.zero;
    final paused = _pausedUntil;
    if (paused != null && paused.isAfter(now)) wait = paused.difference(now);
    final last = _last;
    if (last != null) {
      final g = gap - now.difference(last);
      if (g > wait) wait = g;
    }
    return wait;
  }

  void wake(Duration delay, VoidCallback run) {
    _timer?.cancel();
    _timer = Timer(delay, run);
  }

  void cancel() => _timer?.cancel();
}

/// An area as saved on the device.
class _SavedArea {
  const _SavedArea({
    required this.stations,
    required this.complete,
    required this.at,
  });

  final List<FuelStation> stations;
  final bool complete;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'v': 1,
    'at': at.millisecondsSinceEpoch,
    'complete': complete,
    'stations': [for (final s in stations) s.toJson()],
  };

  static _SavedArea? fromJson(Map<String, Object?> json) {
    final at = json['at'];
    final list = json['stations'];
    if (json['v'] != 1 || at is! num || list is! List) return null;
    return _SavedArea(
      stations: [for (final s in list) ?FuelStation.fromJson(s)],
      complete: json['complete'] == true,
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
}
