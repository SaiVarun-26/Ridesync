import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase_auth_repository.dart';
import '../../domain/app_user.dart';
import '../../domain/auth_repository.dart';

/// Exposes the [FirebaseAuth] singleton as an overridable dependency.
///
/// Kept as a provider (rather than referenced directly) so tests can override
/// it with a fake without the repository reaching for a global singleton.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Exposes the [FirebaseFirestore] singleton as an overridable dependency.
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// The app's [AuthRepository], wired to the Firebase-backed implementation.
///
/// Presentation code depends on this provider's [AuthRepository] type only,
/// never on the concrete class or on Firebase. Tests override this provider
/// with a mock repository to exercise UI and routing in isolation.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

/// Reactive authentication state: emits the current [AppUser] or `null`.
///
/// The router watches this to decide where to send the user. On cold start the
/// stream's first emission is still pending — callers must treat
/// [AsyncLoading] as "not yet known" (show splash), distinct from a resolved
/// `null` ("signed out"), to avoid flashing onboarding at returning users.
final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
