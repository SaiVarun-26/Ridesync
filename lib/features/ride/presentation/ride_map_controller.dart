import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../../room/domain/room.dart';
import '../../room/domain/room_status.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../data/background_tracking_service.dart';
import '../domain/geo_point.dart';
import '../domain/live/location_sync_service.dart';
import '../domain/live/ride_notification.dart';
import '../domain/live/rider_trail.dart';
import '../domain/location_fix.dart';
import '../domain/location_repository.dart';
import '../domain/rider_location.dart';
import '../domain/stats/ride_stats.dart';
import '../domain/stats/ride_stats_service.dart';
import 'providers/ride_init_providers.dart';
import 'providers/ride_map_providers.dart';

/// GPS quality shown to the rider.
enum GpsStatus { searching, weak, locked }

/// A rider drawn on the map.
class LiveRider {
  const LiveRider({
    required this.uid,
    required this.colorId,
    required this.point,
    required this.headingDegrees,
    required this.isMoving,
    required this.isMe,
    this.displayName,
    this.speedMps,
    this.receivedAtMs,
  });

  final String uid;
  final String? colorId;

  /// The rider's chosen name, if they set one.
  final String? displayName;

  /// Latest ground speed in meters per second, when known.
  final double? speedMps;

  /// When this device last received the rider's position (epoch millis);
  /// `null` for this rider.
  final int? receivedAtMs;
  final GeoPoint point;
  final double? headingDegrees;

  /// Whether to show a direction of travel.
  final bool isMoving;
  final bool isMe;
}

/// Everything the live map renders.
class RideMapState {
  const RideMapState({
    this.myFix,
    this.riders = const {},
    this.trails = const {},
    this.colorIds = const {},
    this.myStats,
    this.isConnected = true,
    this.gps = GpsStatus.searching,
    this.nowMs = 0,
    this.isFinalSaved = false,
  });

  /// This device's latest fix; `null` until the first one arrives.
  final LocationFix? myFix;

  /// Riders drawn as live markers (including this one), by uid. A rider who is
  /// offline has no marker.
  final Map<String, LiveRider> riders;

  /// Recent paths of every rider in the room, by uid. Kept while a rider is
  /// offline, so their history is still there when they return.
  final Map<String, RiderTrail> trails;

  /// Each room member's claimed color id, by uid, so trails keep their color
  /// while their owner has no marker.
  final Map<String, String?> colorIds;

  /// This rider's running statistics; `null` until the first GPS fix.
  final RideStats? myStats;

  final bool isConnected;
  final GpsStatus gps;

  /// Clock used to fade trails consistently across a frame.
  final int nowMs;

  /// Whether this rider's final record has been saved (or given up on) after
  /// the host ended the ride.
  final bool isFinalSaved;

  /// Current ground speed, in km/h.
  double get speedKmh => (myFix?.speedMps ?? 0) * _kmhPerMps;

  static const double _kmhPerMps = 3.6;
}

/// Runs the live map for one room: shares this rider's position, follows
/// everyone else's, and keeps their trails. The map widgets only render
/// [RideMapState]; they hold no ride logic.
class RideMapController extends Notifier<RideMapState> {
  RideMapController(this._code);

  final String _code;
  final Map<String, RiderLocation> _remote = {};

  /// When each remote rider's latest position reached this device.
  final Map<String, int> _receivedAt = {};
  Room? _room;
  late LocationSyncService _sync;
  late RideStatsService _stats;
  late LocationRepository _location;
  late BackgroundTrackingService _tracking;
  Timer? _notificationTimer;
  bool _finishing = false;
  RideNotificationContent _lastNotification = RideNotificationContent.initial;

  /// Below this speed no heading is shown (GPS heading is noise when
  /// stationary).
  static const double _movingSpeedMps = 1;

  /// Accuracy worse than this reads as a weak signal.
  static const double _weakAccuracyMeters = 25;

  /// A fix older than this means GPS is searching again.
  static const Duration _staleFixAfter = Duration(seconds: 20);

  /// How often to re-check GPS freshness and expire old trail points.
  static const Duration _housekeepingInterval = Duration(seconds: 5);

  /// How often to refresh the background notification's live stats.
  static const Duration _notificationInterval = Duration(seconds: 2);

  /// How long to wait for one last GPS fix when the ride ends. Kept short: the
  /// host only waits a few seconds for every rider to finish.
  static const Duration _finalFixTimeout = Duration(seconds: 2);

  /// Upper bound on saving the final record, e.g. when there is no signal. The
  /// database keeps queued writes and delivers them when the signal returns.
  static const Duration _finishTimeout = Duration(seconds: 8);

  @override
  RideMapState build() {
    final rooms = ref.read(roomRepositoryProvider);
    _location = ref.read(locationRepositoryProvider);
    _tracking = ref.read(backgroundTrackingServiceProvider);
    _sync = LocationSyncService(
      location: ref.read(locationRepositoryProvider),
      liveLocations: ref.read(liveLocationRepositoryProvider),
      connection: rooms.watchConnection(),
      roomCode: _code,
    );
    _stats = RideStatsService(
      repository: ref.read(rideStatsRepositoryProvider),
      roomCode: _code,
    );

    final fixSub = _sync.fixes.listen(_onMyFix);
    final statsSub = _stats.updates.listen(_onMyStats);
    final liveSub = ref
        .read(liveLocationRepositoryProvider)
        .watchChanges(code: _code)
        .listen(_onRemoteChange);
    final connectionSub = rooms.watchConnection().listen((connected) {
      if (state.isConnected != connected) {
        state = _copy(isConnected: connected);
      }
    });
    final housekeeping = Timer.periodic(
      _housekeepingInterval,
      (_) => _housekeep(),
    );
    _room = ref.read(roomStreamProvider(_code)).value;
    ref.listen<AsyncValue<Room?>>(roomStreamProvider(_code), (_, next) {
      _room = next.value;
      _publishRiders();
      _maybeFinish(next.value);
    });
    _notificationTimer = Timer.periodic(
      _notificationInterval,
      (_) => _refreshNotification(),
    );
    ref.onDispose(() {
      housekeeping.cancel();
      _notificationTimer?.cancel();
      unawaited(fixSub.cancel());
      unawaited(statsSub.cancel());
      unawaited(liveSub.cancel());
      unawaited(connectionSub.cancel());
      unawaited(_sync.stop());
      // Saves the ride one last time before it stops recording.
      unawaited(_stats.dispose());
      unawaited(_tracking.stop());
    });

    _sync.start();
    unawaited(_stats.start());
    unawaited(_tracking.start(initialContent: _lastNotification));
    // A rider who opens the map after the host already ended the ride.
    Future<void>.microtask(() => _maybeFinish(_room));
    return RideMapState(nowMs: _nowMs());
  }

  /// Reacts to the host ending the ride. Runs once.
  ///
  /// While the room is `ending` this rider saves their final record. If the
  /// room is already `ended`, the record is closed and there is nothing left
  /// to save, so tracking is only stopped.
  void _maybeFinish(Room? room) {
    if (_finishing || room == null || !ref.mounted) return;
    final status = room.status;
    if (status != RoomStatus.ending && status != RoomStatus.ended) return;
    _finishing = true;
    unawaited(_finishRide(saveFinalRecord: status == RoomStatus.ending));
  }

  /// Takes a last GPS fix, freezes and saves the record, then stops GPS, live
  /// location sharing and the background service, whatever happens.
  Future<void> _finishRide({required bool saveFinalRecord}) async {
    _notificationTimer?.cancel();
    try {
      if (saveFinalRecord) {
        final point = await _location.currentPosition(
          timeout: _finalFixTimeout,
        );
        if (point != null) {
          _stats.addFix(LocationFix(point: point, timestamp: DateTime.now()));
        }
        await _stats
            .finish(endedAtMs: _nowMs())
            .timeout(_finishTimeout, onTimeout: () => null);
      }
    } finally {
      if (ref.mounted) state = _copy(isFinalSaved: true);
      await _sync.stop();
      await _tracking.stop();
    }
  }

  /// Pushes the latest distance, speed and duration into the live
  /// notification, only when the text actually changed.
  void _refreshNotification() {
    if (!ref.mounted) return;
    final content = RideNotificationContent.fromRide(
      stats: state.myStats,
      speedMps: state.myFix?.speedMps ?? 0,
      nowMs: _nowMs(),
    );
    if (content.body == _lastNotification.body) return;
    _lastNotification = content;
    unawaited(_tracking.update(content));
  }

  void _onMyStats(RideStats stats) {
    if (ref.mounted) state = _copy(myStats: stats);
  }

  void _onMyFix(LocationFix fix) {
    _stats.addFix(fix);
    final uid = _myUid;
    final now = _nowMs();
    state = _copy(
      myFix: fix,
      gps: _gpsFor(fix, now),
      nowMs: now,
      trails: uid == null ? null : _appendTrail(uid, fix.point, now),
    );
    _publishRiders();
  }

  void _onRemoteChange(RiderLocationChange change) {
    final now = _nowMs();
    switch (change) {
      case RiderLocationUpdated(:final location):
        if (location.uid == _myUid) return;
        _remote[location.uid] = location;
        _receivedAt[location.uid] = now;
        state = _copy(
          nowMs: now,
          trails: _appendTrail(location.uid, location.point, now),
        );
      case RiderLocationRemoved(:final uid):
        _remote.remove(uid);
        _receivedAt.remove(uid);
    }
    _publishRiders();
  }

  /// Rebuilds the visible rider set: members who are online and sharing a
  /// position, plus this rider.
  ///
  /// Only the live *marker* depends on being online. A rider's trail and color
  /// are kept for as long as they are in the room, so a rider who backgrounds
  /// the app or loses signal keeps their history and simply continues it on
  /// return.
  void _publishRiders() {
    if (!ref.mounted) return;
    final room = _room;
    final myUid = _myUid;
    final riders = <String, LiveRider>{};
    if (room != null) {
      for (final location in _remote.values) {
        final member = room.memberByUid(location.uid);
        if (member == null || !member.online) continue;
        riders[location.uid] = LiveRider(
          uid: location.uid,
          colorId: member.colorId,
          point: location.point,
          headingDegrees: location.headingDegrees,
          isMoving: (location.speedMps ?? 0) >= _movingSpeedMps,
          isMe: false,
          displayName: member.displayName,
          speedMps: location.speedMps,
          receivedAtMs: _receivedAt[location.uid],
        );
      }
    }
    final fix = state.myFix;
    if (myUid != null && fix != null) {
      riders[myUid] = LiveRider(
        uid: myUid,
        colorId: room?.memberByUid(myUid)?.colorId,
        point: fix.point,
        headingDegrees: fix.headingDegrees,
        isMoving: (fix.speedMps ?? 0) >= _movingSpeedMps,
        isMe: true,
        displayName: room?.memberByUid(myUid)?.displayName,
        speedMps: fix.speedMps,
      );
    }
    final trails = {
      for (final entry in state.trails.entries)
        if (entry.key == myUid || (room?.memberByUid(entry.key) != null))
          entry.key: entry.value,
    };
    state = _copy(
      riders: riders,
      trails: trails,
      colorIds: {
        if (room != null)
          for (final member in room.members) member.uid: member.colorId,
      },
    );
  }

  void _housekeep() {
    if (!ref.mounted) return;
    final now = _nowMs();
    final fix = state.myFix;
    state = _copy(
      nowMs: now,
      gps: fix == null ? GpsStatus.searching : _gpsFor(fix, now),
    );
  }

  Map<String, RiderTrail> _appendTrail(String uid, GeoPoint point, int now) {
    final current = state.trails[uid] ?? const RiderTrail();
    final next = current.append(point, now);
    if (identical(next, current)) return state.trails;
    return {...state.trails, uid: next};
  }

  GpsStatus _gpsFor(LocationFix fix, int nowMs) {
    final age = nowMs - fix.timestamp.millisecondsSinceEpoch;
    if (age > _staleFixAfter.inMilliseconds) return GpsStatus.searching;
    final accuracy = fix.point.accuracyMeters;
    return accuracy != null && accuracy > _weakAccuracyMeters
        ? GpsStatus.weak
        : GpsStatus.locked;
  }

  String? get _myUid => ref.read(authRepositoryProvider).currentUser?.uid;

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  RideMapState _copy({
    LocationFix? myFix,
    Map<String, LiveRider>? riders,
    Map<String, RiderTrail>? trails,
    Map<String, String?>? colorIds,
    RideStats? myStats,
    bool? isConnected,
    GpsStatus? gps,
    int? nowMs,
    bool? isFinalSaved,
  }) {
    return RideMapState(
      isFinalSaved: isFinalSaved ?? state.isFinalSaved,
      myFix: myFix ?? state.myFix,
      riders: riders ?? state.riders,
      trails: trails ?? state.trails,
      colorIds: colorIds ?? state.colorIds,
      myStats: myStats ?? state.myStats,
      isConnected: isConnected ?? state.isConnected,
      gps: gps ?? state.gps,
      nowMs: nowMs ?? state.nowMs,
    );
  }
}
