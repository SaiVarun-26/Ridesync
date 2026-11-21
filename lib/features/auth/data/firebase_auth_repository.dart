import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';
import 'user_profile_dto.dart';

/// Firebase-backed implementation of [AuthRepository]: Google Sign-In through
/// Firebase Auth, with the profile and synced preferences in the Firestore
/// document `users/{uid}`.
///
/// This is the only file in the auth feature that imports Firebase or Google
/// Sign-In. Every public method returns a [Result]; platform exceptions are
/// mapped to domain [Failure]s here.
///
/// Offline: Firestore persists writes on the device and uploads them when the
/// connection returns, so profile and preference saves never block on the
/// network. A save that has not reached the server within [_writeTimeout] is
/// reported as done (it is queued), and [UserProfile.hasPendingWrites] tells
/// the UI it is still syncing.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth,
       _firestore = firestore,
       _googleOverride = googleSignIn;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn? _googleOverride;

  GoogleSignIn get _google => _googleOverride ?? GoogleSignIn.instance;

  /// `GoogleSignIn.initialize` must run exactly once per app run.
  static Future<void>? _googleReady;

  static const Duration _writeTimeout = Duration(seconds: 6);
  static const Duration _readTimeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(UserProfileDto.collection);

  @override
  Stream<AppUser?> authStateChanges() {
    // `userChanges` (unlike `authStateChanges`) also fires when an anonymous
    // account is linked to Google, which changes `isAnonymous`.
    return _auth.userChanges().map(_mapFirebaseUser).distinct();
  }

  @override
  AppUser? get currentUser => _mapFirebaseUser(_auth.currentUser);

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    try {
      await _ensureGoogleReady();
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return const Failed(
          AuthFailure(message: 'Google did not return a sign-in token.'),
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final user = await _signInOrLink(credential);
      if (user == null) {
        return const Failed(
          AuthFailure(message: 'Sign-in succeeded but no user was returned.'),
        );
      }

      final dto = await _upsertAccount(
        uid: user.uid,
        email: account.email,
        photoUrl: account.photoUrl ?? user.photoURL,
      );
      return Success(
        dto?.toAppUser() ??
            AppUser(
              uid: user.uid,
              email: account.email,
              photoUrl: account.photoUrl ?? user.photoURL,
            ),
      );
    } on GoogleSignInException catch (e) {
      return Failed(_mapGoogleException(e));
    } on FirebaseAuthException catch (e, stack) {
      return Failed(_mapAuthException(e, stack));
    } on FirebaseException catch (e, stack) {
      return Failed(_mapFirestoreException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  /// Signs in with [credential]. A legacy anonymous session is linked instead,
  /// keeping its uid and every ride saved under it; when the Google account
  /// already belongs to another RideSync account, that account is signed into.
  Future<User?> _signInOrLink(AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        final linked = await current.linkWithCredential(credential);
        return linked.user;
      } on FirebaseAuthException catch (e) {
        const takenCodes = {
          'credential-already-in-use',
          'email-already-in-use',
          'provider-already-linked',
        };
        if (!takenCodes.contains(e.code)) rethrow;
        debugPrint(
          'Google account already has a RideSync account (${e.code}); '
          'signing into it instead of linking.',
        );
        final signedIn = await _auth.signInWithCredential(
          e.credential ?? credential,
        );
        return signedIn.user;
      }
    }
    final signedIn = await _auth.signInWithCredential(credential);
    return signedIn.user;
  }

  /// Creates the profile on first sign-in, or refreshes the account details
  /// on an existing one. Never touches the rider name. Best effort: a failure
  /// here does not undo the sign-in (the rider-name screen writes the
  /// profile again).
  Future<UserProfileDto?> _upsertAccount({
    required String uid,
    required String? email,
    required String? photoUrl,
  }) async {
    final doc = _users.doc(uid);
    try {
      final existing = await doc.get().timeout(_readTimeout);
      final fields = existing.exists
          ? UserProfileDto.accountFields(
              uid: uid,
              email: email,
              photoUrl: photoUrl,
            )
          : UserProfileDto.createFields(
              uid: uid,
              email: email,
              photoUrl: photoUrl,
            );
      await _write(doc, fields);
      final base = existing.exists
          ? UserProfileDto.fromSnapshot(existing)
          : UserProfileDto(uid: uid);
      return UserProfileDto(
        uid: uid,
        displayName: base.displayName,
        email: email ?? base.email,
        photoUrl: photoUrl ?? base.photoUrl,
        createdAt: base.createdAt,
        soloColorId: base.soloColorId,
        fuelEnabled: base.fuelEnabled,
      );
    } catch (e) {
      debugPrint('Saving the profile after sign-in failed: $e');
      return null;
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
      return Success(
        UserProfileDto.fromSnapshot(
          snapshot,
        ).toAppUser(isAnonymous: user.isAnonymous),
      );
    } on FirebaseException catch (e, stack) {
      return Failed(_mapFirestoreException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _users
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        // A miss in the device's cache is not an answer yet: wait for the
        // server rather than briefly reporting "no profile".
        .where((s) => s.exists || !s.metadata.isFromCache)
        .map(
          (s) => s.exists
              ? UserProfileDto.fromSnapshot(
                  s,
                ).toProfile(hasPendingWrites: s.metadata.hasPendingWrites)
              : null,
        );
  }

  @override
  Future<Result<void>> updateRiderName(String riderName) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const Failed(
        AuthFailure(message: 'You must be signed in to update your name.'),
      );
    }
    final name = riderName.trim();
    if (name.isEmpty) {
      return const Failed(UnexpectedFailure(message: 'Enter a rider name.'));
    }
    try {
      final doc = _users.doc(user.uid);
      await _write(
        doc,
        UserProfileDto.riderNameFields(
          uid: user.uid,
          riderName: name,
          isCreate: !await _exists(doc),
        ),
      );
      return const Success(null);
    } on FirebaseException catch (e, stack) {
      return Failed(_mapFirestoreException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<void>> updatePreferences({
    String? soloColorId,
    bool? fuelEnabled,
  }) async {
    if (soloColorId == null && fuelEnabled == null) {
      return const Success(null);
    }
    final user = _auth.currentUser;
    if (user == null) {
      return const Failed(AuthFailure(message: 'You must be signed in.'));
    }
    try {
      final doc = _users.doc(user.uid);
      await _write(
        doc,
        UserProfileDto.preferenceFields(
          uid: user.uid,
          isCreate: !await _exists(doc),
          soloColorId: soloColorId,
          fuelEnabled: fuelEnabled,
        ),
      );
      return const Success(null);
    } on FirebaseException catch (e, stack) {
      return Failed(_mapFirestoreException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<void>> refreshProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const Failed(AuthFailure(message: 'You must be signed in.'));
    }
    try {
      await _users
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_readTimeout);
      return const Success(null);
    } on TimeoutException catch (e) {
      return Failed(NetworkFailure(cause: e));
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
      try {
        await _ensureGoogleReady();
        await _google.signOut();
      } catch (e) {
        // Firebase is already signed out; the Google session only decides
        // whether the account picker remembers the last account.
        debugPrint('Google sign-out failed: $e');
      }
      return const Success(null);
    } on FirebaseAuthException catch (e, stack) {
      return Failed(_mapAuthException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  Future<void> _ensureGoogleReady() {
    return _googleReady ??= _google.initialize().catchError((Object e) {
      _googleReady = null; // allow a retry
      throw e;
    });
  }

  /// Whether the profile document exists. Answered from the device when
  /// offline; when unknown, assumes it does (it is created at sign-in), which
  /// only means `createdAt` is not stamped again.
  Future<bool> _exists(DocumentReference<Map<String, dynamic>> doc) async {
    try {
      return (await doc.get().timeout(_readTimeout)).exists;
    } catch (_) {
      try {
        return (await doc.get(
          const GetOptions(source: Source.cache),
        )).exists;
      } catch (_) {
        return true;
      }
    }
  }

  /// Merge-writes [fields]. Firestore applies the write on the device at once
  /// and uploads it when it can; waiting is capped so an offline save still
  /// completes (it stays queued).
  Future<void> _write(
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> fields,
  ) async {
    try {
      await doc.set(fields, SetOptions(merge: true)).timeout(_writeTimeout);
    } on TimeoutException {
      debugPrint('Profile save queued until the connection returns.');
    }
  }

  /// Maps a Firebase [User] to the domain [AppUser], or `null`. The rider
  /// name is not taken from the auth account (for Google that is the Google
  /// name); it comes from the profile.
  AppUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      photoUrl: user.photoURL,
      email: user.email,
      isAnonymous: user.isAnonymous,
    );
  }

  Failure _mapGoogleException(GoogleSignInException e) {
    debugPrint('GoogleSignInException(${e.code}): ${e.description}');
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted => const SignInCancelled(),
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError => const AuthFailure(
        message: 'Google Sign-In is not set up for this build yet.',
      ),
      GoogleSignInExceptionCode.uiUnavailable => const AuthFailure(
        message: 'Google Sign-In could not open. Please try again.',
      ),
      _ => AuthFailure(cause: e),
    };
  }

  Failure _mapAuthException(FirebaseAuthException e, StackTrace stack) {
    debugPrint('FirebaseAuthException(${e.code}): ${e.message}');
    return switch (e.code) {
      'network-request-failed' => NetworkFailure(cause: e),
      'operation-not-allowed' => const AuthFailure(
        message: 'Google sign-in is not enabled for this project.',
      ),
      'user-disabled' => const AuthFailure(
        message: 'This account has been disabled.',
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
