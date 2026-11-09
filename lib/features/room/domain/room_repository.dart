import '../../../core/errors/result.dart';
import 'ride_mode.dart';
import 'room.dart';

/// Contract for ride-room lifecycle and live membership.
///
/// Rooms are live data and therefore live in the Realtime Database (per the
/// project's datastore split). The presentation layer depends only on this
/// interface; the Firebase-backed implementation is injected via Riverpod,
/// keeping the repository mockable.
///
/// All fallible operations return a [Result]; platform exceptions are mapped to
/// domain [Failure]s inside the implementation and never cross this boundary.
abstract interface class RoomRepository {
  /// Creates a new room with a freshly generated unique 6-character code and
  /// adds the creator as host. Returns the created [Room] on success.
  Future<Result<Room>> createRoom({required String name});

  /// Joins an existing room by [code], adding the current user as a member who
  /// is not yet ready.
  ///
  /// Fails with [NotFoundFailure] if no room exists for the code.
  Future<Result<Room>> joinRoom({required String code});

  /// Atomically claims [colorId] for the current user within [code].
  ///
  /// Uses a database transaction so two members can never hold the same color:
  /// the first writer wins and any contender receives a [ConflictFailure]. If
  /// the user already holds a different color, it is released. Fails while the
  /// rider is marked ready, so a ready rider's identity cannot change.
  Future<Result<void>> claimColor({
    required String code,
    required String colorId,
  });

  /// Marks the current (non-host) rider ready or not ready in room [code].
  ///
  /// Becoming ready requires a claimed color. The host never marks ready.
  Future<Result<void>> setReady({required String code, required bool ready});

  /// Moves room [code] from the lobby to ride-type selection.
  ///
  /// Host only, and only when every rider is ready and has a color. Every
  /// client observing the room reacts to the status change, so riders never
  /// navigate manually.
  Future<Result<void>> continueToRideMode({required String code});

  /// Records the host's chosen ride [mode] for room [code] and moves the room
  /// to ride initialization. Both ride types prepare every device first.
  ///
  /// Host only, and only while the room is choosing its mode.
  Future<Result<void>> chooseRideMode({
    required String code,
    required RideMode mode,
  });

  /// Records whether the current rider's device finished ride initialization
  /// in room [code].
  Future<Result<void>> setInitialized({
    required String code,
    required bool initialized,
  });

  /// Moves room [code] on from initialization: free roam starts riding, a
  /// guided ride moves to destination planning.
  ///
  /// Host only, and only while initializing and once every connected rider
  /// reports initialized.
  Future<Result<void>> completeInitialization({required String code});

  /// Starts a planned guided ride in room [code], moving it from planning to
  /// riding.
  ///
  /// Host only, only while planning, and only when every rider is connected.
  /// The security rules additionally require a generated route.
  Future<Result<void>> startGuidedRide({required String code});

  /// Whether this client is currently connected to the database. Emits on
  /// every change, starting with the current state.
  Stream<bool> watchConnection();

  /// Leaves the room, removing the current user's membership and releasing the
  /// color they had claimed.
  Future<Result<void>> leaveRoom({required String code});

  /// Keeps the current user's presence in room [code] accurate while the
  /// returned stream is listened to.
  ///
  /// Every time the client (re)connects to the database, the member is marked
  /// online again and the disconnect handler is re-armed. A disconnect marks
  /// the member offline and resets their ready state. Emits the connection
  /// state.
  Stream<bool> trackPresence({required String code});

  /// A live stream of the room identified by [code].
  ///
  /// Emits a new [Room] whenever any member, claim, or metadata value changes,
  /// and `null` if the room ceases to exist.
  Stream<Room?> watchRoom({required String code});
}
