/// Lifecycle state of a ride room.
///
/// Persisted to the Realtime Database as the raw [wireValue] string so the
/// stored format stays stable even if enum names change. The status is the
/// single source of truth for which screen every rider is on: the host changes
/// it, and every client follows it. Live data lives in RTDB per the project's
/// datastore split.
enum RoomStatus {
  /// Members are joining, claiming colors, and getting ready.
  lobby('lobby'),

  /// Everyone is ready; the host is choosing between a guided ride and free
  /// roam.
  choosingMode('choosingMode'),

  /// Guided ride, after initialization: the host is choosing the destination
  /// and generating the shared route.
  planning('planning'),

  /// Every rider is preparing their device for the ride (room sync, location,
  /// map resources). Once every connected rider reports initialized, the host
  /// advances to [planning] (guided) or [riding] (free roam).
  initializing('initializing'),

  /// The ride is in progress.
  riding('riding'),

  /// The host has ended the ride. Every rider is saving their final stats and
  /// route; the host writes the ride summary once they have finished (or a
  /// short timeout passes).
  ending('ending'),

  /// The ride is over and its summary is written. Everyone moves to results.
  ended('ended');

  const RoomStatus(this.wireValue);

  /// The exact string stored in the database for this status.
  final String wireValue;

  /// Whether a rider who is not yet in the room can still join it.
  ///
  /// Joining stays open for the whole life of a ride, including while it is
  /// being ridden, and closes only once the host has started ending it.
  bool get acceptsNewRiders => this != ending && this != ended;

  /// Whether the group has moved past the lobby, so a rider joining now is
  /// joining a ride that is already under way.
  bool get isUnderway => this != lobby;

  /// Resolves a persisted [wireValue] back to a [RoomStatus], defaulting to
  /// [RoomStatus.lobby] for unknown or missing values.
  static RoomStatus fromWire(String? value) {
    for (final status in RoomStatus.values) {
      if (status.wireValue == value) return status;
    }
    return RoomStatus.lobby;
  }
}
