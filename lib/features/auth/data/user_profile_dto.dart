import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';

/// Data-layer mapper between the Firestore `users/{uid}` document and the
/// domain [AppUser].
///
/// The field set here is the single source of truth for the profile schema and
/// must stay in lockstep with the Firestore security rules, which allow-list
/// exactly: `uid`, `displayName`, `photoUrl`, `createdAt`, `updatedAt`. Sending
/// any other key would be rejected by the rules, so all field names are defined
/// as constants and reused rather than written inline.
class UserProfileDto {
  const UserProfileDto({required this.uid, this.displayName, this.photoUrl});

  final String uid;
  final String? displayName;
  final String? photoUrl;

  // Firestore collection + field names. Centralized to avoid magic strings and
  // to keep the wire schema aligned with the security rules.
  static const String collection = 'users';
  static const String fieldUid = 'uid';
  static const String fieldDisplayName = 'displayName';
  static const String fieldPhotoUrl = 'photoUrl';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';

  /// Builds a DTO from a domain [AppUser].
  factory UserProfileDto.fromDomain(AppUser user) => UserProfileDto(
    uid: user.uid,
    displayName: user.displayName,
    photoUrl: user.photoUrl,
  );

  /// Reconstructs a DTO from a Firestore snapshot.
  ///
  /// Tolerates missing optional fields and ignores server-managed timestamps,
  /// which the domain entity does not model.
  factory UserProfileDto.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return UserProfileDto(
      uid: (data[fieldUid] as String?) ?? snapshot.id,
      displayName: data[fieldDisplayName] as String?,
      photoUrl: data[fieldPhotoUrl] as String?,
    );
  }

  /// Maps this DTO to the domain [AppUser].
  AppUser toDomain() =>
      AppUser(uid: uid, displayName: displayName, photoUrl: photoUrl);

  /// Serializes for a merge write.
  ///
  /// [isCreate] controls whether `createdAt` is stamped — it is written once on
  /// creation and never touched again, so the durable creation time is
  /// preserved by later merge updates. `updatedAt` is always refreshed.
  /// Timestamps use [FieldValue.serverTimestamp] so they are authoritative and
  /// independent of client clocks.
  ///
  /// The returned map contains only the allow-listed fields, satisfying both
  /// the `create` and `update` branches of the Firestore security rules.
  Map<String, dynamic> toFirestore({required bool isCreate}) {
    return <String, dynamic>{
      fieldUid: uid,
      fieldDisplayName: displayName,
      fieldPhotoUrl: photoUrl,
      if (isCreate) fieldCreatedAt: FieldValue.serverTimestamp(),
      fieldUpdatedAt: FieldValue.serverTimestamp(),
    };
  }
}
