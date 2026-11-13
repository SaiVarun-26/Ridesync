import 'ride_mode.dart';
import 'room_member.dart';
import 'room_status.dart';

/// A ride room: the shared lobby identified by a short [code].
///
/// Domain entity assembled by the data layer from the Realtime Database
/// `rooms/{code}` node. Holds the room metadata plus the current member list,
/// and owns the readiness rules that gate starting the ride.
class Room {
  const Room({
    required this.code,
    required this.name,
    required this.hostUid,
    required this.status,
    required this.mode,
    required this.members,
    required this.createdAt,
  });

  /// The 6-character join code; also the room's database key.
  final String code;

  /// Human-friendly ride name chosen by the host.
  final String name;

  /// Uid of the member who created the room.
  final String hostUid;

  /// Current lifecycle state.
  final RoomStatus status;

  /// The ride type chosen by the host, or `null` until one is chosen.
  final RideMode? mode;

  /// All current members, host first, then in join order.
  final List<RoomMember> members;

  /// Epoch millis when the room was created, as stamped by the server.
  final int? createdAt;

  /// The set of color ids already claimed by members.
  Set<String> get claimedColorIds => {
    for (final m in members)
      if (m.colorId != null) m.colorId!,
  };

  /// Color ids claimed by members other than [uid]. The rider's own color is
  /// excluded so it can be shown as selected rather than taken.
  Set<String> colorsClaimedByOthers(String? uid) => {
    for (final m in members)
      if (m.uid != uid && m.colorId != null) m.colorId!,
  };

  /// The host's member entry, or `null` if the host has left.
  RoomMember? get host => memberByUid(hostUid);

  /// Members counted as ready, including the implicitly-ready host.
  int get readyCount => members.where((m) => m.countsAsReady).length;

  /// Whether every joined rider is ready.
  bool get everyoneReady =>
      members.isNotEmpty && members.every((m) => m.countsAsReady);

  /// Whether the host may continue: every rider is ready and every rider,
  /// including the host, has a color (their identity for the ride).
  bool get canContinue => everyoneReady && members.every((m) => m.hasColor);

  /// Whether every member is currently connected.
  bool get everyoneConnected =>
      members.isNotEmpty && members.every((m) => m.online);

  /// Members currently connected to the room.
  List<RoomMember> get connectedMembers =>
      members.where((m) => m.online).toList();

  /// Connected members whose device has finished ride initialization.
  int get initializedCount =>
      connectedMembers.where((m) => m.isInitialized).length;

  /// Whether every connected rider has finished initialization. Riders who are
  /// offline are not waited for, so one dropped phone cannot strand the group.
  bool get everyoneConnectedInitialized {
    final connected = connectedMembers;
    return connected.isNotEmpty && connected.every((m) => m.isInitialized);
  }

  /// Looks up a member by [uid], or returns `null`.
  RoomMember? memberByUid(String uid) {
    for (final m in members) {
      if (m.uid == uid) return m;
    }
    return null;
  }
}
