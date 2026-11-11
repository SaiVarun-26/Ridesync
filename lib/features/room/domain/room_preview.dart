/// A look at a room before joining it: enough to tell the rider what they are
/// about to join and whether they still can.
class RoomPreview {
  const RoomPreview({
    required this.code,
    required this.name,
    required this.riderCount,
    required this.isOpen,
    required this.isMember,
  });

  final String code;
  final String name;

  /// How many riders are in the room now.
  final int riderCount;

  /// Whether the room still accepts new riders. A room is open until the host
  /// starts the ride.
  final bool isOpen;

  /// Whether the viewer is already in the room.
  final bool isMember;

  /// Whether the viewer can enter: new riders only while the room is open,
  /// riders already in the room always.
  bool get canJoin => isOpen || isMember;
}
