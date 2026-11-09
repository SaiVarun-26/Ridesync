/// Domain representation of the signed-in user.
///
/// This is the only user type the presentation and routing layers depend on.
/// It is deliberately framework-agnostic: no Firebase, no Flutter imports. The
/// data layer maps Firebase's `User` and the Firestore profile document into
/// this entity, so the rest of the app never couples to the SDK.
///
/// RideSync uses anonymous authentication, so [uid] is always present (Firebase
/// assigns a stable uid even to anonymous sessions), while [displayName] and
/// [photoUrl] are optional. [photoUrl] is reserved for future compatibility —
/// V1 captures no image and performs no upload — but the field is modelled now
/// so the durable profile schema is stable.
class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.photoUrl,
  });

  /// The stable, immutable Firebase user id. Present for anonymous users too.
  final String uid;

  /// Optional, user-chosen display name. `null` when the user skipped it.
  final String? displayName;

  /// Optional profile picture URL. Always `null` in V1 (no upload); modelled
  /// for forward compatibility only.
  final String? photoUrl;

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
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: identical(displayName, _unset)
          ? this.displayName
          : displayName as String?,
      photoUrl:
          identical(photoUrl, _unset) ? this.photoUrl : photoUrl as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser &&
          other.uid == uid &&
          other.displayName == displayName &&
          other.photoUrl == photoUrl);

  @override
  int get hashCode => Object.hash(uid, displayName, photoUrl);

  @override
  String toString() =>
      'AppUser(uid: $uid, displayName: $displayName, photoUrl: $photoUrl)';

  /// Sentinel used by [copyWith] to detect omitted nullable arguments.
  static const Object _unset = Object();
}
