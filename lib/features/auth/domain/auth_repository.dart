import '../../../core/errors/result.dart';
import 'app_user.dart';

/// Contract for authentication and the durable user profile.
///
/// The presentation layer depends only on this interface, never on Firebase.
/// The concrete implementation lives in the data layer
/// ([FirebaseAuthRepository]) and is injected via Riverpod, which keeps this
/// repository fully mockable in tests.
///
/// All fallible operations return a [Result] rather than throwing, so callers
/// handle the [Failure] path explicitly and platform exceptions never leak
/// across the layer boundary.
abstract interface class AuthRepository {
  /// Emits the current [AppUser] whenever the authentication state changes,
  /// and `null` when there is no signed-in user.
  ///
  /// The stream replays the latest value to new listeners and begins with the
  /// restored session on cold start (anonymous sessions persist across
  /// launches), so routing can react to auth without an imperative check.
  Stream<AppUser?> authStateChanges();

  /// The currently signed-in user, or `null` if none.
  ///
  /// Synchronous convenience for one-off reads (e.g. guards). Prefer
  /// [authStateChanges] for anything that must stay reactive.
  AppUser? get currentUser;

  /// Signs the user in anonymously and ensures their durable profile exists.
  ///
  /// When [displayName] is provided and non-empty it is persisted to the
  /// profile. On success the resolved [AppUser] is returned; on failure a
  /// mapped [Failure] (auth, network, or unexpected) is returned.
  Future<Result<AppUser>> signInAnonymously({String? displayName});

  /// Loads the signed-in user's durable profile (the source of truth for the
  /// display name). Falls back to the session-only identity if no profile
  /// document exists yet. Fails with [AuthFailure] when signed out.
  Future<Result<AppUser>> loadCurrentProfile();

  /// Updates the signed-in user's display name in the durable profile.
  ///
  /// Requires an active session. Passing `null` or an empty string clears the
  /// stored name.
  Future<Result<AppUser>> updateDisplayName(String? displayName);

  /// Signs the current user out, ending the local session.
  Future<Result<void>> signOut();
}
