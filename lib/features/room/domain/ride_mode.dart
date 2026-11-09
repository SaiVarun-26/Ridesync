/// How the group rides, chosen by the host after everyone is ready.
///
/// Stored on the room (`meta/mode`) as [wireValue]. A room has no mode until
/// the host chooses one, which is modelled as a `null` [RideMode].
enum RideMode {
  /// Everyone follows one destination and the same planned route.
  guided('guided'),

  /// No destination; the app only keeps the group together.
  free('free');

  const RideMode(this.wireValue);

  /// The exact string stored in the database for this mode.
  final String wireValue;

  /// Resolves a persisted [wireValue] back to a [RideMode], or `null` when no
  /// mode has been chosen (or the value is unknown).
  static RideMode? fromWire(String? value) {
    for (final mode in RideMode.values) {
      if (mode.wireValue == value) return mode;
    }
    return null;
  }
}
