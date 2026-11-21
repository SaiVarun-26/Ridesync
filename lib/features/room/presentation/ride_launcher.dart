import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/rider_palette.dart';
import '../../auth/presentation/providers/auth_providers.dart';
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
  RideLauncher(this._rooms, {String? Function()? soloColorId})
    : _soloColorId = soloColorId ?? _none;

  final RoomRepository _rooms;

  /// The rider's chosen solo colour (from their synced profile), if any.
  final String? Function() _soloColorId;

  static String? _none() => null;

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

    // Nobody else is choosing, so the rider simply gets their own colour.
    final colorId = soloColorFor(_soloColorId());
    final steps = <Future<Result<void>> Function()>[
      () => _rooms.claimColor(code: room.code, colorId: colorId),
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

  /// The colour a solo ride uses: the rider's chosen [preferred] when it is
  /// one of the rider colours, else the first.
  static String soloColorFor(String? preferred) {
    for (final color in RiderPalette.colors) {
      if (color.id == preferred) return color.id;
    }
    return RiderPalette.colors.first.id;
  }
}

/// Starts rides.
final rideLauncherProvider = Provider<RideLauncher>((ref) {
  return RideLauncher(
    ref.watch(roomRepositoryProvider),
    // Read at the moment a solo ride starts, so a colour just changed in
    // Edit Profile applies straight away.
    soloColorId: () => ref.read(userProfileProvider).value?.soloColorId,
  );
});
