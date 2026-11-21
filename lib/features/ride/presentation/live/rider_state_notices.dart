import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../room/domain/rider_ride_state.dart';
import '../../../room/domain/room.dart';
import '../../../room/presentation/providers/room_providers.dart';

/// What another rider did with their own ride.
enum RiderStateChange { paused, resumed, completed }

/// One rider's pause, resume or finish, to tell the group.
@immutable
class RiderStateNotice {
  const RiderStateNotice({
    required this.id,
    required this.uid,
    required this.name,
    required this.change,
  });

  /// Increases with every notice.
  final int id;
  final String uid;
  final String name;
  final RiderStateChange change;

  String get message => switch (change) {
    RiderStateChange.paused => '$name paused the ride.',
    RiderStateChange.resumed => '$name resumed riding.',
    RiderStateChange.completed => '$name completed the ride.',
  };
}

/// The latest pause, resume or finish by another rider in room [code]. Never
/// this rider's own: nobody is told about themselves.
final riderStateNoticeProvider = NotifierProvider.autoDispose
    .family<RiderStateNotices, RiderStateNotice?, String>(
      RiderStateNotices.new,
    );

class RiderStateNotices extends Notifier<RiderStateNotice?> {
  RiderStateNotices(this._code);

  final String _code;

  /// Each rider's state as last seen; `null` until the room is first seen,
  /// so states already in place when the map opens are not announced.
  Map<String, RiderRideState?>? _last;
  int _id = 0;

  @override
  RiderStateNotice? build() {
    ref.listen<AsyncValue<Room?>>(
      roomStreamProvider(_code),
      (_, next) => _onRoom(next.value),
      fireImmediately: true,
    );
    return null;
  }

  void _onRoom(Room? room) {
    if (room == null) return;
    final now = {for (final m in room.members) m.uid: m.rideState};
    final last = _last;
    _last = now;
    if (last == null) return;
    final me = ref.read(authStateChangesProvider).value?.uid;
    for (final member in room.members) {
      if (member.uid == me) continue;
      final before = last[member.uid];
      final after = member.rideState;
      if (before == after) continue;
      final change = switch (after) {
        RiderRideState.paused => RiderStateChange.paused,
        RiderRideState.finished => RiderStateChange.completed,
        RiderRideState.riding when before == RiderRideState.paused =>
          RiderStateChange.resumed,
        _ => null,
      };
      if (change == null) continue;
      final name = member.displayName?.trim();
      state = RiderStateNotice(
        id: ++_id,
        uid: member.uid,
        name: name == null || name.isEmpty ? 'A rider' : name,
        change: change,
      );
    }
  }
}
