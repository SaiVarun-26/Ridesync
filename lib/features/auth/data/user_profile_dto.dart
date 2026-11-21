import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';
import '../domain/user_profile.dart';

/// Data-layer mapper for the Firestore `users/{uid}` document: the rider's
/// profile and synced preferences.
///
/// The field set here is the single source of truth for the profile schema and
/// must stay in lockstep with the Firestore security rules, which allow-list
/// exactly: `uid`, `displayName`, `email`, `photoUrl`, `preferences`,
/// `createdAt`, `updatedAt`. Sending any other key is rejected by the rules,
/// so all field names are constants.
///
/// `displayName` holds the rider name the rider chose (never the Google
/// account's name). It keeps its historical field name so rooms and rides
/// created before Google Sign-In keep resolving it.
class UserProfileDto {
  const UserProfileDto({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.createdAt,
    this.soloColorId,
    this.fuelEnabled,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final DateTime? createdAt;
  final String? soloColorId;
  final bool? fuelEnabled;

  static const String collection = 'users';
  static const String fieldUid = 'uid';
  static const String fieldDisplayName = 'displayName';
  static const String fieldEmail = 'email';
  static const String fieldPhotoUrl = 'photoUrl';
  static const String fieldPreferences = 'preferences';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';

  /// Keys inside the `preferences` map.
  static const String prefSoloColorId = 'soloColorId';
  static const String prefFuelEnabled = 'fuelEnabled';

  /// Reconstructs a DTO from a Firestore snapshot, tolerating missing or
  /// mistyped fields (older documents carry only `uid` and `displayName`).
  factory UserProfileDto.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => UserProfileDto.fromMap(snapshot.id, snapshot.data());

  factory UserProfileDto.fromMap(String id, Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    final prefs = map[fieldPreferences];
    final prefsMap = prefs is Map ? prefs : const <String, dynamic>{};
    final created = map[fieldCreatedAt];
    return UserProfileDto(
      uid: _string(map[fieldUid]) ?? id,
      displayName: _string(map[fieldDisplayName]),
      email: _string(map[fieldEmail]),
      photoUrl: _string(map[fieldPhotoUrl]),
      createdAt: created is Timestamp ? created.toDate() : null,
      soloColorId: _string(prefsMap[prefSoloColorId]),
      fuelEnabled: prefsMap[prefFuelEnabled] is bool
          ? prefsMap[prefFuelEnabled] as bool
          : null,
    );
  }

  /// The identity other features use (rider name as [AppUser.displayName]).
  AppUser toAppUser({bool isAnonymous = false}) => AppUser(
    uid: uid,
    displayName: displayName,
    photoUrl: photoUrl,
    email: email,
    isAnonymous: isAnonymous,
  );

  UserProfile toProfile({bool hasPendingWrites = false}) => UserProfile(
    uid: uid,
    riderName: displayName,
    email: email,
    photoUrl: photoUrl,
    memberSince: createdAt,
    soloColorId: soloColorId,
    fuelEnabled: fuelEnabled,
    hasPendingWrites: hasPendingWrites,
  );

  /// The document written the first time a rider signs in with Google. No
  /// rider name yet: they choose one next.
  static Map<String, dynamic> createFields({
    required String uid,
    String? email,
    String? photoUrl,
  }) => <String, dynamic>{
    fieldUid: uid,
    fieldEmail: ?email,
    fieldPhotoUrl: ?photoUrl,
    fieldCreatedAt: FieldValue.serverTimestamp(),
    fieldUpdatedAt: FieldValue.serverTimestamp(),
  };

  /// Refreshes the Google account details on an existing document, leaving
  /// the rider name and preferences untouched.
  static Map<String, dynamic> accountFields({
    required String uid,
    String? email,
    String? photoUrl,
  }) => <String, dynamic>{
    fieldUid: uid,
    fieldEmail: ?email,
    fieldPhotoUrl: ?photoUrl,
    fieldUpdatedAt: FieldValue.serverTimestamp(),
  };

  /// Sets the rider name. [isCreate] stamps `createdAt` for a document that
  /// does not exist yet.
  static Map<String, dynamic> riderNameFields({
    required String uid,
    required String riderName,
    required bool isCreate,
  }) => <String, dynamic>{
    fieldUid: uid,
    fieldDisplayName: riderName,
    if (isCreate) fieldCreatedAt: FieldValue.serverTimestamp(),
    fieldUpdatedAt: FieldValue.serverTimestamp(),
  };

  /// Merges preference changes; omitted preferences are left as they are.
  static Map<String, dynamic> preferenceFields({
    required String uid,
    required bool isCreate,
    String? soloColorId,
    bool? fuelEnabled,
  }) => <String, dynamic>{
    fieldUid: uid,
    fieldPreferences: <String, dynamic>{
      prefSoloColorId: ?soloColorId,
      prefFuelEnabled: ?fuelEnabled,
    },
    if (isCreate) fieldCreatedAt: FieldValue.serverTimestamp(),
    fieldUpdatedAt: FieldValue.serverTimestamp(),
  };

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
