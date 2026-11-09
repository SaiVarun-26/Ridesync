import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../domain/ride_mode.dart';
import '../domain/room.dart';
import '../domain/room_status.dart';
import 'providers/room_providers.dart';

/// The screen every rider should be on for [room]'s current status.
///
/// The room status in RTDB is the single source of truth for the group's
/// position in the flow. Only the host changes it; every client maps it to a
/// route here, so the whole group moves together.
String roomFlowPath(Room room) {
  return switch (room.status) {
    RoomStatus.lobby => AppRoutes.lobbyPath(room.code),
    RoomStatus.choosingMode => AppRoutes.rideModePath(room.code),
    RoomStatus.planning => AppRoutes.planningPath(room.code),
    RoomStatus.initializing => AppRoutes.initializingPath(room.code),
    RoomStatus.riding => room.mode == RideMode.free
        ? AppRoutes.freeRidePath(room.code)
        : AppRoutes.ridePath(room.code),
    RoomStatus.ended => AppRoutes.home,
  };
}

/// Plays a hand-off (such as the ride-start sequence) before the rider leaves
/// the current screen for the room's next stage.
typedef RoomFlowTransition = Future<void> Function(Room room);

/// Moves this rider to the correct screen whenever room [code] changes stage.
///
/// Call from the `build` method of every room-flow screen, passing that
/// screen's own path as [currentPath]. When the host advances the room, every
/// rider's screen sees the new status and navigates, so no rider ever has to
/// navigate manually. If [beforeLeaving] is given, it is awaited first; it
/// must return the same future for repeated calls while it runs.
void listenToRoomFlow(
  WidgetRef ref,
  BuildContext context, {
  required String code,
  required String currentPath,
  RoomFlowTransition? beforeLeaving,
}) {
  ref.listen<AsyncValue<Room?>>(roomStreamProvider(code), (_, next) async {
    final room = next.value;
    if (room == null || !context.mounted) return;
    final target = roomFlowPath(room);
    if (target == currentPath) return;
    if (beforeLeaving != null) await beforeLeaving(room);
    if (context.mounted) context.go(target);
  });
}
