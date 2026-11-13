import '../domain/ride_mode.dart';
import '../domain/room.dart';
import '../domain/room_member.dart';
import '../domain/room_status.dart';

/// Realtime Database path and field names for rooms.
///
/// Centralized so the wire schema has a single source of truth and the rules,
/// reads, and writes all agree. Rooms are live data and therefore stored in
/// RTDB.
abstract final class RoomPaths {
  static const String rooms = 'rooms';

  static const String meta = 'meta';
  static const String members = 'members';
  static const String claims = 'claims';
  static const String claimColors = 'colors';

  // meta fields
  static const String metaCode = 'code';
  static const String metaName = 'name';
  static const String metaHostUid = 'hostUid';
  static const String metaStatus = 'status';
  static const String metaMode = 'mode';
  static const String metaCreatedAt = 'createdAt';

  // member fields
  static const String memberUid = 'uid';
  static const String memberDisplayName = 'displayName';
  static const String memberColorId = 'colorId';
  static const String memberReady = 'ready';
  static const String memberInitialized = 'initialized';
  static const String memberOnline = 'online';
  static const String memberJoinedAt = 'joinedAt';

  const RoomPaths._();
}

/// Maps the Realtime Database `rooms/{code}` node to a domain [Room].
abstract final class RoomDto {
  /// Builds a [Room] from the raw RTDB snapshot value for a room node.
  ///
  /// Tolerates missing child nodes (e.g. a room with no members yet). Returns
  /// `null` if [value] is not a map (room absent).
  static Room? fromSnapshot(String code, Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);

    final meta = _asMap(map[RoomPaths.meta]);
    final membersRaw = _asMap(map[RoomPaths.members]);

    final hostUid = meta[RoomPaths.metaHostUid] as String? ?? '';

    final members = <RoomMember>[];
    membersRaw.forEach((key, memberValue) {
      final member = _memberFromSnapshot(
        uid: key as String,
        value: memberValue,
        hostUid: hostUid,
      );
      if (member != null) members.add(member);
    });

    // Stable ordering: host first, then by join time, then uid.
    members.sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      final at = a.joinedAt ?? 0;
      final bt = b.joinedAt ?? 0;
      if (at != bt) return at.compareTo(bt);
      return a.uid.compareTo(b.uid);
    });

    return Room(
      code: meta[RoomPaths.metaCode] as String? ?? code,
      name: meta[RoomPaths.metaName] as String? ?? '',
      hostUid: hostUid,
      status: RoomStatus.fromWire(meta[RoomPaths.metaStatus] as String?),
      mode: RideMode.fromWire(meta[RoomPaths.metaMode] as String?),
      members: members,
      createdAt: _asInt(meta[RoomPaths.metaCreatedAt]),
    );
  }

  static RoomMember? _memberFromSnapshot({
    required String uid,
    required Object? value,
    required String hostUid,
  }) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    return RoomMember(
      uid: map[RoomPaths.memberUid] as String? ?? uid,
      displayName: map[RoomPaths.memberDisplayName] as String?,
      colorId: map[RoomPaths.memberColorId] as String?,
      isHost: uid == hostUid,
      isReady: map[RoomPaths.memberReady] as bool? ?? false,
      isInitialized: map[RoomPaths.memberInitialized] as bool? ?? false,
      online: map[RoomPaths.memberOnline] as bool? ?? false,
      joinedAt: _asInt(map[RoomPaths.memberJoinedAt]),
    );
  }

  static Map<Object?, Object?> _asMap(Object? value) =>
      value is Map ? Map<Object?, Object?>.from(value) : <Object?, Object?>{};

  static int? _asInt(Object? value) => value is int
      ? value
      : value is num
      ? value.toInt()
      : null;
}
