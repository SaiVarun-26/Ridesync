import '../../../auth/domain/auth_repository.dart';
import '../../../room/domain/ride_mode.dart';
import '../../../room/domain/room_repository.dart';
import '../location_repository.dart';
import '../map_style_repository.dart';
import 'init_task.dart';
import 'tasks.dart';

/// The ordered initialization steps for a ride of the given [mode].
///
/// This is the single place that decides what "ready to ride" means. Adding a
/// step for a future milestone is one more entry in this list; the engine and
/// the screen render whatever the plan contains.
///
/// Free roam and guided rides share the same steps: a guided ride initializes
/// before its destination is planned, so there is no route to prepare yet.
List<InitTask> buildRideInitPlan({
  required RideMode mode,
  required String roomCode,
  required RoomRepository rooms,
  required AuthRepository auth,
  required LocationRepository location,
  required MapStyleRepository mapStyles,
}) {
  final shared = <InitTask>[
    RoomSyncTask(rooms: rooms, roomCode: roomCode),
    RiderIdentityTask(auth: auth, rooms: rooms, roomCode: roomCode),
    LocationPermissionTask(location: location),
    CurrentLocationTask(location: location),
    MapResourcesTask(mapStyles: mapStyles),
  ];
  return switch (mode) {
    RideMode.free => shared,
    RideMode.guided => shared,
  };
}
