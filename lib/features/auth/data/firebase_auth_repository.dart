import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import 'user_profile_dto.dart';

/// Firebase-backed implementation of [AuthRepository].
///
/// This is the only file in the auth feature that imports Firebase, confining
/// the dependency to the data layer. [FirebaseAuth] and [FirebaseFirestore] are
/// injected via the constructor rather than read from their singletons, so the
/// repository is fully mockable (e.g. with `firebase_auth_mocks` and
/// `fake_cloud_firestore`) without touching a real project.
///
/// Every public method returns a [Result]; low-level [FirebaseException]s are
/// caught here and mapped to domain [Failure]s so they never cross the layer
/// boundary.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(UserProfileDto.collection);

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map(_mapFirebaseUser);
  }

  @override
  AppUser? get currentUser => _mapFirebaseUser(_auth.currentUser);

  @override
  Future<Result<AppUser>> signInAnonymously({String? displayName}) async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        return const Failed(
          AuthFailure(message: 'Sign-in succeeded but no user was returned.'),
        );
      }

      final normalizedName = _normalizeName(displayName);
      final profile = await _ensureProfile(uid: user.uid, name: normalizedName);
      return Success(profile);
    } on FirebaseAuthException catch (e, stack) {
      return Failed(_mapAuthException(e, stack));
    } on FirebaseException catch (e, stack) {
      return Failed(_mapFirestoreException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<AppUser>> loadCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const Failed(AuthFailure(message: 'You must be signed in.'));
    }
    try {
      final snapshot = await _users.doc(user.uid).get();
      if (!snapshot.exists) {
        return Success(_mapFirebaseUser(user)!);
      }
      return Success(UserProfileDto.fromSnapshot(snapshot).toDomain());
    } on FirebaseException catch (e, stack) {
      return Failed(_mapFirestoreException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<AppUser>> updateDisplayName(String? displayName) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const Failed(
        AuthFailure(message: 'You must be signed in to update your name.'),
      );
    }
    try {
      final normalizedName = _normalizeName(displayName);
      final profile = await _ensureProfile(uid: user.uid, name: normalizedName);
      return Success(profile);
    } on FirebaseException catch (e, stack) {
      return Failed(_mapFirestoreException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      return const Success(null);
    } on FirebaseAuthException catch (e, stack) {
      return Failed(_mapAuthException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  /// Creates or updates the durable `users/{uid}` profile and returns the
  /// resulting domain user.
  ///
  /// Uses a merge write so a single code path handles both first sign-in
  /// (create) and later updates without clobbering server-managed fields such
  /// as `createdAt`. Whether the document already exists determines if
  /// `createdAt` is stamped.
  Future<AppUser> _ensureProfile({
    required String uid,
    required String? name,
  }) async {
    final docRef = _users.doc(uid);
    final existing = await docRef.get();
    final isCreate = !existing.exists;

    final dto = UserProfileDto(uid: uid, displayName: name);
    await docRef.set(
      dto.toFirestore(isCreate: isCreate),
      SetOptions(merge: true),
    );
    return dto.toDomain();
  }

  /// Maps a Firebase [User] to the domain [AppUser], or `null`.
  AppUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      displayName: _normalizeName(user.displayName),
      photoUrl: user.photoURL,
    );
  }

  /// Trims a name and collapses empty strings to `null`.
  String? _normalizeName(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Failure _mapAuthException(FirebaseAuthException e, StackTrace stack) {
    debugPrint('FirebaseAuthException(${e.code}): ${e.message}');
    return switch (e.code) {
      'network-request-failed' => NetworkFailure(cause: e),
      'operation-not-allowed' => const AuthFailure(
        message: 'Anonymous sign-in is not enabled for this project.',
      ),
      'too-many-requests' => const AuthFailure(
        message: 'Too many attempts. Please wait a moment and try again.',
      ),
      _ => AuthFailure(cause: e),
    };
  }

  Failure _mapFirestoreException(FirebaseException e, StackTrace stack) {
    debugPrint('FirebaseException(${e.code}): ${e.message}');
    return switch (e.code) {
      'unavailable' || 'deadline-exceeded' => NetworkFailure(cause: e),
      'permission-denied' => const AuthFailure(
        message: 'You do not have permission to update this profile.',
      ),
      _ => UnexpectedFailure(cause: e),
    };
  }

  Failure _unexpected(Object error, StackTrace stack) {
    debugPrint('Unexpected auth error: $error\n$stack');
    return UnexpectedFailure(cause: error);
  }
}
