import '../../../core/errors/result.dart';

/// A ride's name as the whole group sees it.
class SharedRideName {
  const SharedRideName({required this.name, required this.isFinal});

  final String name;

  /// Whether the host has named the ride yet.
  final bool isFinal;
}

/// Contract for saving ride names.
///
/// There are two names. The *shared* name belongs to the ride and is set once,
/// by the host, after the ride. Each rider's own history entry also holds a
/// name, which starts as the shared one and can be renamed later by that rider
/// alone.
abstract interface class RideNameStore {
  /// Saves [name] as the ride's shared name, on the room and on the ride's
  /// summary together, and marks the ride as named. Host only.
  Future<Result<void>> saveSharedName({
    required String code,
    required String name,
  });

  /// The ride's shared name, or `null` when it cannot be read.
  Future<SharedRideName?> readSharedName(String code);

  /// Saves [name] on [uid]'s own history entry for ride [code] (and on the
  /// device's saved copies of it), and clears the entry's "waiting for the
  /// host's name" mark. Fails when the ride is not in the rider's history.
  Future<Result<void>> saveMyName({
    required String uid,
    required String code,
    required String name,
  });
}
