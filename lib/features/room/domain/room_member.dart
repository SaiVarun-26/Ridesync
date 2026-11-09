/// A participant in a ride room.
///
/// Framework-agnostic domain entity: no Firebase, no Flutter. The data layer
/// maps a Realtime Database `members/{uid}` node into this. A rider's only
/// visual identity is their claimed color, so [colorId] is `null` until they
/// claim one.
class RoomMember {
  const RoomMember({
    required this.uid,
    required this.displayName,
    required this.colorId,
    required this.isHost,
    required this.isReady,
    required this.isInitialized,
    required this.online,
    required this.joinedAt,
  });

  /// The member's stable Firebase uid.
  final String uid;

  /// Optional display name; `null` when the user never set one.
  final String? displayName;

  /// Claimed rider color id (see [RiderPalette]); `null` until claimed.
  final String? colorId;

  /// Whether this member created the room. The host never marks ready.
  final bool isHost;

  /// Whether this (non-host) rider has marked themselves ready to ride. Reset
  /// automatically when the rider disconnects.
  final bool isReady;

  /// Whether this rider's device finished ride initialization. Written only by
  /// the rider's own client and reset automatically when they disconnect.
  final bool isInitialized;

  /// Live presence flag, cleared automatically on disconnect.
  final bool online;

  /// Epoch millis when the member joined, as stamped by the server.
  final int? joinedAt;

  /// Whether this member has claimed a color.
  bool get hasColor => colorId != null;

  /// Whether this member counts as ready for the ride to continue. The host is
  /// implicitly ready; everyone else must press Ready.
  bool get countsAsReady => isHost || isReady;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoomMember &&
          other.uid == uid &&
          other.displayName == displayName &&
          other.colorId == colorId &&
          other.isHost == isHost &&
          other.isReady == isReady &&
          other.isInitialized == isInitialized &&
          other.online == online &&
          other.joinedAt == joinedAt);

  @override
  int get hashCode => Object.hash(
        uid,
        displayName,
        colorId,
        isHost,
        isReady,
        isInitialized,
        online,
        joinedAt,
      );
}
