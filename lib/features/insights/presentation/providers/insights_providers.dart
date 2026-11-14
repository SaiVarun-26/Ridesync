import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../history/domain/ride_history_entry.dart';
import '../../../history/presentation/providers/ride_details_providers.dart';
import '../../../history/presentation/providers/ride_history_providers.dart';
import '../../../history/presentation/widgets/ride_details_sections.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/open_meteo_weather_service.dart';
import '../../data/rtdb_ride_weather_repository.dart';
import '../../domain/achievements/achievement.dart';
import '../../domain/recap/ride_recap.dart';
import '../../domain/recap/ride_recap_service.dart';
import '../../domain/weather/weather_repositories.dart';
import '../../domain/weather/weather_snapshot.dart';

/// Current conditions, from Open-Meteo.
final weatherServiceProvider = Provider<WeatherService>((ref) {
  return OpenMeteoWeatherService();
});

/// Each ride's weather snapshot.
final rideWeatherRepositoryProvider = Provider<RideWeatherRepository>((ref) {
  return RtdbRideWeatherRepository(
    database: ref.watch(firebaseDatabaseProvider),
    cache: ref.watch(rideCacheProvider),
  );
});

/// Takes each ride's weather snapshot once, as it starts.
final rideWeatherRecorderProvider = Provider<RideWeatherRecorder>((ref) {
  return RideWeatherRecorder(
    service: ref.watch(weatherServiceProvider),
    repository: ref.watch(rideWeatherRepositoryProvider),
  );
});

/// The weather a ride started in, or `null` if none was recorded.
final rideWeatherProvider = FutureProvider.autoDispose
    .family<WeatherSnapshot?, String>((ref, code) {
      return ref.watch(rideWeatherRepositoryProvider).load(code);
    });

/// Builds and remembers ride recaps.
final rideRecapServiceProvider = Provider<RideRecapService>((ref) {
  return RideRecapService(
    details: ref.watch(rideDetailsRepositoryProvider),
    weather: ref.watch(rideWeatherRepositoryProvider),
    nameOf: riderNameOf,
  );
});

/// The recap of ride [code] for the signed-in rider. Built once, in the
/// background, and then served from memory wherever it is shown.
final rideRecapProvider = FutureProvider.autoDispose.family<RideRecap, String>((
  ref,
  code,
) async {
  final details = await ref.watch(rideDetailsProvider(code).future);
  final uid = ref.watch(authStateChangesProvider.select((a) => a.value?.uid));
  final previous = await _previousRides(ref, uid);
  return ref
      .read(rideRecapServiceProvider)
      .fromDetails(details, myUid: uid, previousRides: previous);
});

/// The rider's other rides to measure personal records against: the loaded
/// history (or, before it has loaded, the device's copy of it) plus their
/// longest and fastest rides from their whole history. The recap only counts
/// the ones that ended before the ride it describes.
Future<List<PastRide>> _previousRides(Ref ref, String? uid) async {
  if (uid == null) return const [];
  final repository = ref.read(rideHistoryRepositoryProvider);
  var entries = ref.read(rideHistoryProvider).entries;
  if (entries.isEmpty) entries = await repository.cached(uid);
  final bests = await repository.personalBests(uid: uid);
  return pastRidesFrom(_merge(entries, bests));
}

/// [a] and [b] together, each ride once.
List<RideHistoryEntry> _merge(
  Iterable<RideHistoryEntry> a,
  Iterable<RideHistoryEntry> b,
) => {
  for (final e in [...a, ...b]) e.code: e,
}.values.toList();

/// [entries] as [PastRide]s, for personal records.
List<PastRide> pastRidesFrom(Iterable<RideHistoryEntry> entries) => [
  for (final e in entries)
    PastRide(
      code: e.code,
      endedAtMs: e.endedAtMs,
      distanceMeters: e.distanceMeters,
      maxSpeedMps: e.maxSpeedMps,
    ),
];

/// Keeps the recap highlights on the rider's history up to date: any ride in
/// the list without them gets its recap built (one ride at a time, in the
/// background) and its highlights saved with it, so history cards show the
/// score, achievements and weather from then on.
///
/// Watched by the screens that show history. It does nothing while there is
/// nothing to fill.
final recapHighlightsSyncProvider = Provider.autoDispose<void>((ref) {
  final sync = _HighlightsSync(ref);
  ref
    ..listen<RideHistoryState>(
      rideHistoryProvider,
      (_, next) => unawaited(sync.fill(next.entries)),
      fireImmediately: true,
    )
    ..onDispose(sync.stop);
});

class _HighlightsSync {
  _HighlightsSync(this._ref);

  final Ref _ref;
  bool _running = false;
  bool _again = false;
  bool _stopped = false;

  /// Rides already tried in this session, so one that cannot be loaded is not
  /// retried again and again.
  static final Set<String> _tried = {};

  /// Most rides filled per session, so a long history is caught up over a
  /// few launches instead of all at once.
  static const int _maxPerSession = 12;
  static int _filled = 0;

  void stop() => _stopped = true;

  Future<void> fill(List<RideHistoryEntry> entries) async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      final uid = _ref.read(authStateChangesProvider).value?.uid;
      if (uid == null) return;
      final service = _ref.read(rideRecapServiceProvider);
      final repository = _ref.read(rideHistoryRepositoryProvider);
      final history = _ref.read(rideHistoryProvider.notifier);
      List<RideHistoryEntry>? bests;
      for (final entry in List<RideHistoryEntry>.of(entries)) {
        if (_stopped || _filled >= _maxPerSession) return;
        if (entry.highlights != null || !_tried.add(entry.code)) continue;
        // Fetched once per pass, and only when there is something to fill.
        bests ??= await repository.personalBests(uid: uid);
        final earlier = [
          for (final e in _merge(entries, bests))
            if (e.endedAtMs < entry.endedAtMs) e,
        ];
        final recap = await service.load(
          entry.code,
          myUid: uid,
          previousRides: pastRidesFrom(earlier),
        );
        if (recap == null || _stopped) continue;
        _filled++;
        final highlights = recap.highlights;
        await repository.saveHighlights(
          uid: uid,
          code: entry.code,
          highlights: highlights,
        );
        // Shown either way; if saving failed it is worked out again next
        // time instead.
        history.applyHighlights(entry.code, highlights);
      }
    } finally {
      _running = false;
      if (_again && !_stopped) {
        _again = false;
        unawaited(fill(_ref.read(rideHistoryProvider).entries));
      }
    }
  }
}
