import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ridesync/app/app.dart';
import 'package:ridesync/core/errors/failure.dart';
import 'package:ridesync/core/errors/result.dart';
import 'package:ridesync/features/auth/domain/app_user.dart';
import 'package:ridesync/features/auth/domain/auth_repository.dart';
import 'package:ridesync/features/auth/presentation/providers/auth_providers.dart';

/// A signed-out [AuthRepository] so the app can boot without Firebase.
class _SignedOutAuthRepository implements AuthRepository {
  static const _signedOut = AuthFailure(message: 'Signed out.');

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);

  @override
  AppUser? get currentUser => null;

  @override
  Future<Result<AppUser>> loadCurrentProfile() async =>
      const Failed(_signedOut);

  @override
  Future<Result<AppUser>> signInAnonymously({String? displayName}) async =>
      const Failed(_signedOut);

  @override
  Future<Result<AppUser>> updateDisplayName(String? displayName) async =>
      const Failed(_signedOut);

  @override
  Future<Result<void>> signOut() async => const Success(null);
}

void main() {
  testWidgets('Signed-out user boots to onboarding', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedOutAuthRepository()),
        ],
        child: const RideSyncApp(),
      ),
    );

    // Splash resolves the (signed-out) auth state, then redirects. The name
    // field pulses forever while empty, so settle with bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('RideSync'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
