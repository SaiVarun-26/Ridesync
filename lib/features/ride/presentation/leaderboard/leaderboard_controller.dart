import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/rider_palette.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../room/domain/ride_mode.dart';
import '../../../room/domain/room.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/rtdb_ride_event_repository.dart';
import '../../domain/guidance/route_geometry.dart';
import '../../domain/guidance/route_guide.dart';
import '../../domain/leaderboard/leaderboard.dart';
import '../../domain/leaderboard/leaderboard_calculator.dart';
import '../../domain/live/rider_trail.dart';
import '../providers/guidance_providers.dart';
import '../providers/ride_map_providers.dart';
import '../ride_map_controller.dart';

/// The name shown for [rider]: their own, else their colour's, else "Rider".
String leaderboardNameOf(LiveRider? rider) {
  final name = rider?.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return RiderPalette.colorById(rider?.colorId)?.label ?? 'Rider';
}

/// The ride's event log on the database.
final rideEventRepositoryProvider = Provider<RtdbRideEventRepository>((ref) {
  return RtdbRideEventRepository(
    database: ref.watch(firebaseDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
  );
});

/// The live leaderboard for room [code].
final leaderboardControllerProvider = NotifierProvider.autoDispose
    .family<LeaderboardController, LeaderboardState, String>(
      LeaderboardController.new,
    );

/// A path event ready to announce: the event and the rider's name.
class AnnouncedEvent {
  const AnnouncedEvent({
    required this.id,
    required this.event,
    required this.name,
  });

  /// Increases with every event, so two alike are told apart.
  final int id;
  final RidePathEvent event;
  final String name;

  /// "Rahul has rerouted", "Rahul rejoined the group", …
  String get message => switch ((event.kind, event.guided)) {
    (RidePathEventKind.left, true) => '$name left the planned route',
    (RidePathEventKind.left, false) => '$name has rerouted',
    (RidePathEventKind.rejoined, true) => '$name rejoined the route',
    (RidePathEventKind.rejoined, false) => '$name rejoined the group',
  };
}

/// What the leaderboard shows.
class LeaderboardState {
  const LeaderboardState({
    this.entries = const [],
    this.memberCount = 0,
    this.latest,
    this.log = const [],
  });

  /// Online riders, best first.
  final List<LeaderboardEntry> entries;

  /// Everyone in the ride, online or not.
  final int memberCount;

  /// The newest event about another rider, to show as a banner.
  final AnnouncedEvent? latest;

  /// Every path event of this ride seen by this phone, newest last.
  final List<AnnouncedEvent> log;

  LeaderboardEntry? entryOf(String uid) {
    for (final e in entries) {
      if (e.uid == uid) return e;
    }
    return null;
  }
}

/// Keeps the leaderboard of room [_code] up to date.
///
/// Runs only when a rider's position or trail changes (a GPS update, here or
/// from the group), at most a couple of times a second however many riders
/// report. Uses the live map's own riders and trails and the guided ride's
/// already analysed route; nothing is worked out per frame.
class LeaderboardController extends Notifier<LeaderboardState> {
  LeaderboardController(this._code);

  final String _code;
  final LeaderboardCalculator _calculator = LeaderboardCalculator();
  RouteGeometry? _route;
  bool _guided = false;
  Room? _room;
  Timer? _pending;
  int _lastRunMs = 0;
  int _eventId = 0;

  /// The board is worked out at most this often.
  static const Duration _minInterval = Duration(milliseconds: 500);

  /// Events kept in the in-app log.
  static const int _logLimit = 100;

  @override
  LeaderboardState build() {
    ref.onDispose(() => _pending?.cancel());
    ref.listen<
      (Map<String, LiveRider>, Map<String, RiderTrail>)
    >(rideMapControllerProvider(_code).select((m) => (m.riders, m.trails)), (
      previous,
      next,
    ) {
      if (previous != null &&
          identical(previous.$1, next.$1) &&
          identical(previous.$2, next.$2)) {
        return;
      }
      _schedule();
    });
    ref.listen<AsyncValue<Room?>>(roomStreamProvider(_code), (_, next) {
      _room = next.value;
      final guided = _room?.mode == RideMode.guided;
      if (guided != _guided) {
        _guided = guided;
        _schedule();
      }
    }, fireImmediately: true);
    ref.listen<AsyncValue<RouteGuide?>>(routeGuideProvider(_code), (_, next) {
      final geometry = next.value?.geometry;
      if (!identical(geometry, _route)) {
        _route = geometry;
        _schedule();
      }
    }, fireImmediately: true);
    Future<void>.microtask(_run);
    return const LeaderboardState();
  }

  /// Runs now, or as soon as the minimum interval allows. Updates that arrive
  /// meanwhile are folded into that one run.
  void _schedule() {
    if (_pending != null) return;
    final wait = _minInterval.inMilliseconds - (_nowMs - _lastRunMs);
    _pending = Timer(Duration(milliseconds: wait < 0 ? 0 : wait), _run);
  }

  void _run() {
    _pending?.cancel();
    _pending = null;
    if (!ref.mounted) return;
    _lastRunMs = _nowMs;
    final map = ref.read(rideMapControllerProvider(_code));
    final riders = [
      for (final r in map.riders.values)
        LeaderboardRider(
          uid: r.uid,
          point: r.point,
          isMe: r.isMe,
          speedMps: r.speedMps,
          trail: map.trails[r.uid],
        ),
    ];
    final result = _calculator.update(
      riders: riders,
      route: _guided ? _route : null,
      nowMs: _nowMs,
    );

    var latest = state.latest;
    var log = state.log;
    if (result.events.isNotEmpty) {
      log = [...log];
      final myUid = ref.read(authStateChangesProvider).value?.uid;
      for (final event in result.events) {
        final announced = AnnouncedEvent(
          id: ++_eventId,
          event: event,
          name: _nameOf(map, event.uid),
        );
        log.add(announced);
        if (event.uid == myUid) {
          // Only the rider themselves writes their event to the ride's log.
          unawaited(
            ref.read(rideEventRepositoryProvider).log(code: _code, event: event),
          );
        } else {
          latest = announced;
        }
      }
      if (log.length > _logLimit) log = log.sublist(log.length - _logLimit);
    }

    final members = _room?.members.length ?? riders.length;
    if (latest == state.latest &&
        identical(log, state.log) &&
        members == state.memberCount &&
        _sameEntries(result.entries, state.entries)) {
      return;
    }
    state = LeaderboardState(
      entries: result.entries,
      memberCount: members,
      latest: latest,
      log: log,
    );
  }

  String _nameOf(RideMapState map, String uid) =>
      leaderboardNameOf(map.riders[uid]);

  static bool _sameEntries(List<LeaderboardEntry> a, List<LeaderboardEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static int get _nowMs => DateTime.now().millisecondsSinceEpoch;
}
