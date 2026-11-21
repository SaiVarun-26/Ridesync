/// Where one rider is in their own ride. Every rider manages only their own
/// ride: they pause, resume and finish it themselves, and the group is told.
enum RiderRideState {
  riding('riding'),
  paused('paused'),
  finished('finished');

  const RiderRideState(this.wireValue);

  /// The value stored on the rider's member node.
  final String wireValue;

  static RiderRideState? fromWire(Object? value) {
    for (final s in values) {
      if (s.wireValue == value) return s;
    }
    return null;
  }
}
