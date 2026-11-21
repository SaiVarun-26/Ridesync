/// Domain representation of the signed-in account.
///
/// This is the only account type the presentation and routing layers depend
/// on. It is deliberately framework-agnostic: no Firebase, no Flutter imports.
///
/// [displayName] here is the name the profile resolves to (the rider name the
/// rider chose, see [UserProfile]); the Google account's own name is never
/// used inside RideSync.
class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.photoUrl,
    this.email,
    this.isAnonymous = false,
  });

  /// The stable, immutable Firebase user id. Every ride, history entry and
  /// preference belongs to it.
  final String uid;

  /// The rider name, when known.
  final String? displayName;

  /// The Google account's profile picture, when signed in with Google.
  final String? photoUrl;

  /// The Google account's email, when signed in with Google.
  final String? email;

  /// Whether this is a legacy anonymous session (from before Google Sign-In).
  /// Such a rider is asked to continue with Google, which keeps their uid and
  /// everything saved under it.
  final bool isAnonymous;

  /// Whether the user has provided a non-empty display name.
  bool get hasDisplayName =>
      displayName != null && displayName!.trim().isNotEmpty;

  /// Returns a copy with selectively overridden fields.
  ///
  /// Uses sentinel [Object] markers so an explicit `null` can be distinguished
  /// from "leave unchanged" for the nullable fields.
  AppUser copyWith({
    String? uid,
    Object? displayName = _unset,
    Object? photoUrl = _unset,
    Object? email = _unset,
    bool? isAnonymous,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: identical(displayName, _unset)
          ? this.displayName
          : displayName as String?,
      photoUrl: identical(photoUrl, _unset)
          ? this.photoUrl
          : photoUrl as String?,
      email: identical(email, _unset) ? this.email : email as String?,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser &&
          other.uid == uid &&
          other.displayName == displayName &&
          other.photoUrl == photoUrl &&
          other.email == email &&
          other.isAnonymous == isAnonymous);

  @override
  int get hashCode =>
      Object.hash(uid, displayName, photoUrl, email, isAnonymous);

  @override
  String toString() =>
      'AppUser(uid: $uid, displayName: $displayName, anonymous: $isAnonymous)';

  /// Sentinel used by [copyWith] to detect omitted nullable arguments.
  static const Object _unset = Object();
}
