import 'dart:async';

import '../../../auth/domain/auth_repository.dart';
import '../../../room/domain/room_repository.dart';
import '../location_repository.dart';
import '../map_style_repository.dart';
import 'init_task.dart';

/// Confirms a live connection to the database and a loaded copy of the room.
///
/// Waits (showing "Reconnecting…") while offline, because a cached room is not
/// proof that this rider is in sync with the group.
class RoomSyncTask implements InitTask {
  RoomSyncTask({required RoomRepository rooms, required String roomCode})
    : _rooms = rooms,
      _roomCode = roomCode;

  final RoomRepository _rooms;
  final String _roomCode;

  static const String _reconnecting = 'Reconnecting…';

  @override
  String get id => 'roomSync';

  @override
  String get label => 'Room Synced';

  @override
  Stream<InitTaskUpdate> run() {
    StreamSubscription<bool>? connectionSub;
    StreamSubscription<Object?>? roomSub;
    bool? connected;
    var hasRoom = false;
    late final StreamController<InitTaskUpdate> controller;

    void evaluate() {
      if (controller.isClosed) return;
      if (connected == false) {
        controller.add(const InitTaskUpdate.waiting(_reconnecting));
      } else if (connected == true && hasRoom) {
        controller.add(const InitTaskUpdate.done());
        unawaited(controller.close());
      }
    }

    controller = StreamController<InitTaskUpdate>(
      onListen: () {
        connectionSub = _rooms.watchConnection().listen((value) {
          connected = value;
          evaluate();
        }, onError: controller.addError);
        roomSub = _rooms.watchRoom(code: _roomCode).listen((room) {
          hasRoom = room != null;
          evaluate();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await connectionSub?.cancel();
        await roomSub?.cancel();
      },
    );
    return controller.stream;
  }
}

/// Confirms the rider is signed in and is a member of this room.
class RiderIdentityTask implements InitTask {
  RiderIdentityTask({
    required AuthRepository auth,
    required RoomRepository rooms,
    required String roomCode,
  }) : _auth = auth,
       _rooms = rooms,
       _roomCode = roomCode;

  final AuthRepository _auth;
  final RoomRepository _rooms;
  final String _roomCode;

  static const String _signingIn = 'Signing you in…';

  @override
  String get id => 'riderIdentity';

  @override
  String get label => 'Rider Verified';

  @override
  Stream<InitTaskUpdate> run() async* {
    var user = _auth.currentUser;
    if (user == null) {
      yield const InitTaskUpdate.waiting(_signingIn);
      user = await _auth.authStateChanges().firstWhere((u) => u != null);
    }
    final uid = user!.uid;
    await _rooms
        .watchRoom(code: _roomCode)
        .firstWhere((room) => room?.memberByUid(uid) != null);
    yield const InitTaskUpdate.done();
  }
}

/// Makes sure the app may read the device location, prompting if possible.
class LocationPermissionTask implements InitTask {
  LocationPermissionTask({required LocationRepository location})
    : _location = location;

  final LocationRepository _location;

  @override
  String get id => 'locationPermission';

  @override
  String get label => 'Location Access';

  @override
  Stream<InitTaskUpdate> run() async* {
    var access = await _location.checkPermission();
    if (access == LocationAccess.denied) {
      access = await _location.requestPermission();
    }
    yield switch (access) {
      LocationAccess.granted => const InitTaskUpdate.done(),
      LocationAccess.denied => const InitTaskUpdate.blocked(
        InitBlocker.locationPermissionDenied,
      ),
      LocationAccess.deniedForever => const InitTaskUpdate.blocked(
        InitBlocker.locationPermissionDeniedForever,
      ),
    };
  }
}

/// Acquires a real GPS fix, waiting for the location service and for signal
/// as long as it takes.
class CurrentLocationTask implements InitTask {
  CurrentLocationTask({required LocationRepository location})
    : _location = location;

  final LocationRepository _location;

  /// How long to wait for a single fix before reporting "Waiting for GPS…"
  /// and trying again.
  static const Duration _fixTimeout = Duration(seconds: 10);

  static const String _waitingForGps = 'Waiting for GPS…';

  @override
  String get id => 'currentLocation';

  @override
  String get label => 'GPS Locked';

  @override
  Stream<InitTaskUpdate> run() async* {
    while (true) {
      if (!await _location.isServiceEnabled()) {
        yield const InitTaskUpdate.waiting(_waitingForGps);
        await _location.watchServiceEnabled().firstWhere((enabled) => enabled);
        yield const InitTaskUpdate.running();
      }
      final fix = await _location.currentPosition(timeout: _fixTimeout);
      if (fix != null) {
        yield const InitTaskUpdate.done();
        return;
      }
      yield const InitTaskUpdate.waiting(_waitingForGps);
    }
  }
}

/// Loads and validates the night map style so the map can apply it at once.
class MapResourcesTask implements InitTask {
  MapResourcesTask({required MapStyleRepository mapStyles})
    : _mapStyles = mapStyles;

  final MapStyleRepository _mapStyles;

  @override
  String get id => 'mapResources';

  @override
  String get label => 'Map Ready';

  @override
  Stream<InitTaskUpdate> run() async* {
    await _mapStyles.loadNightStyle();
    yield const InitTaskUpdate.done();
  }
}
