import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/rider_palette.dart';
import '../../naming/domain/ride_title_generator.dart';
import '../domain/ride_mode.dart';
import '../domain/room.dart';
import '../domain/room_repository.dart';
import 'providers/room_providers.dart';

/// The ways into a ride from the home screen.
///
/// Both create an ordinary ride room through [RoomRepository], so a solo ride
/// is the very same ride as a group one with one rider: the same
/// initialization, guided planning, live map, ending and history. Nothing in
/// the ride itself is duplicated here.
class RideLauncher {
  RideLauncher(this._rooms);

  final RoomRepository _rooms;

  /// A new group ride. Riders join from the lobby; the host names the ride
  /// after it, so it starts under a placeholder name.
  Future<Result<Room>> startGroupRide() {
    return _rooms.createRoom(name: RideNames.groupPlaceholder);
  }

  /// A solo ride of the chosen [mode]: a room with only this rider, taken
  /// straight past the lobby and the ride-type choice into initialization.
  ///
  /// If any step fails, the room is left again and the failure is returned, so
  /// no half-set-up ride is left behind.
  Future<Result<Room>> startSoloRide(RideMode mode) async {
    final created = await _rooms.createRoom(name: RideNames.soloPlaceholder);
    final room = switch (created) {
      Success(:final value) => value,
      Failed() => null,
    };
    if (room == null) return created;

    // Nobody else is choosing, so the first color is as good as any.
    final steps = <Future<Result<void>> Function()>[
      () => _rooms.claimColor(code: room.code, colorId: _soloColor),
      () => _rooms.continueToRideMode(code: room.code),
      () => _rooms.chooseRideMode(code: room.code, mode: mode),
    ];
    for (final step in steps) {
      final result = await step();
      if (result case Failed(:final failure)) {
        await _rooms.leaveRoom(code: room.code);
        return Failed(failure);
      }
    }
    return Success(room);
  }

  static String get _soloColor => RiderPalette.colors.first.id;
}

/// Starts rides.
final rideLauncherProvider = Provider<RideLauncher>((ref) {
  return RideLauncher(ref.watch(roomRepositoryProvider));
});
