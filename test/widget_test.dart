import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ridesync/app/app.dart';
import 'package:ridesync/core/errors/failure.dart';
import 'package:ridesync/core/errors/result.dart';
import 'package:ridesync/features/auth/domain/app_user.dart';
import 'package:ridesync/features/auth/domain/auth_repository.dart';
import 'package:ridesync/features/auth/domain/user_profile.dart';
import 'package:ridesync/features/auth/presentation/providers/auth_providers.dart';

/// A signed-out [AuthRepository] so the app can boot without Firebase.
class _SignedOutAuthRepository implements AuthRepository {
  static const _signedOut = AuthFailure(message: 'Signed out.');

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);

  @override
  AppUser? get currentUser => null;

  @override
  Future<Result<AppUser>> signInWithGoogle() async => const Failed(_signedOut);

  @override
  Future<Result<AppUser>> loadCurrentProfile() async =>
      const Failed(_signedOut);

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      Stream<UserProfile?>.value(null);

  @override
  Future<Result<void>> updateRiderName(String riderName) async =>
      const Failed(_signedOut);

  @override
  Future<Result<void>> updatePreferences({
    String? soloColorId,
    bool? fuelEnabled,
  }) async => const Failed(_signedOut);

  @override
  Future<Result<void>> refreshProfile() async => const Failed(_signedOut);

  @override
  Future<Result<void>> signOut() async => const Success(null);
}

void main() {
  testWidgets('Signed-out user boots to sign-in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedOutAuthRepository()),
        ],
        child: const RideSyncApp(),
      ),
    );

    // Splash resolves the (signed-out) auth state, then redirects. Settle
    // with bounded pumps (the brand mark breathes forever).
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('RideSync'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
