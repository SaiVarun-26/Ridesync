import '../../../core/errors/result.dart';
import 'app_user.dart';
import 'user_profile.dart';

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
  /// Emits the current [AppUser] whenever the session changes (sign-in,
  /// sign-out, or a legacy anonymous account being upgraded to Google), and
  /// `null` when there is no signed-in user. Begins with the restored
  /// session on cold start, so returning riders skip the sign-in screen.
  Stream<AppUser?> authStateChanges();

  /// The currently signed-in user, or `null` if none.
  AppUser? get currentUser;

  /// Signs in with Google.
  ///
  /// A legacy anonymous session is upgraded in place, so its uid, and every
  /// ride saved under it, is kept. A Google account already used on another
  /// phone is signed into instead, bringing its rides. The profile is
  /// created on first sign-in (without a rider name; the rider chooses one
  /// next). Fails with [SignInCancelled] when the rider backs out.
  Future<Result<AppUser>> signInWithGoogle();

  /// Loads the signed-in user's identity with their rider name (the name
  /// shown to other riders). Fails with [AuthFailure] when signed out.
  Future<Result<AppUser>> loadCurrentProfile();

  /// The signed-in rider's profile, live: updates as it changes here or on
  /// another device. `null` while it does not exist yet.
  Stream<UserProfile?> watchProfile(String uid);

  /// Sets the rider name shown inside RideSync. Rides already finished keep
  /// the name they were ridden under.
  Future<Result<void>> updateRiderName(String riderName);

  /// Saves synced preferences; `null` arguments are left unchanged.
  Future<Result<void>> updatePreferences({
    String? soloColorId,
    bool? fuelEnabled,
  });

  /// Fetches the profile from the server, bypassing the device's copy.
  Future<Result<void>> refreshProfile();

  /// Signs the current user out, ending the local session.
  Future<Result<void>> signOut();
}
