import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/ride/presentation/planning_screen.dart';
import '../../features/ride/presentation/ride_initialization_screen.dart';
import '../../features/ride/presentation/ride_map_screen.dart';
import '../../features/ride/presentation/ride_mode_screen.dart';
import '../../features/ride/presentation/ride_results_screen.dart';
import '../../features/ride/presentation/ride_screen.dart';
import '../../features/ride_card/presentation/ride_card_screen.dart';
import '../../features/room/presentation/create_ride_screen.dart';
import '../../features/room/presentation/home_screen.dart';
import '../../features/room/presentation/join_ride_screen.dart';
import '../../features/room/presentation/lobby_screen.dart';
import 'app_routes.dart';

/// Provides the app's [GoRouter].
///
/// The redirect is auth-aware (Milestone 2): it watches
/// [authStateChangesProvider] and routes based on the resolved session. A
/// claimed-color guard for the ride route is added in Milestone 3.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    // Re-run the redirect whenever auth state changes. Wrapping the provider's
    // stream in a [Listenable] lets go_router react to sign-in/sign-out without
    // an imperative navigation call from the UI.
    refreshListenable: _AuthRefreshListenable(ref),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        pageBuilder: (context, state) => _fade(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        pageBuilder: (context, state) => _fade(state, const HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.create,
        name: AppRoutes.createName,
        pageBuilder: (context, state) => _fade(state, const CreateRideScreen()),
      ),
      GoRoute(
        path: AppRoutes.join,
        name: AppRoutes.joinName,
        pageBuilder: (context, state) => _fade(state, const JoinRideScreen()),
      ),
      GoRoute(
        path: AppRoutes.lobby,
        name: AppRoutes.lobbyName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _fade(state, LobbyScreen(roomCode: code));
        },
      ),
      GoRoute(
        path: AppRoutes.rideMode,
        name: AppRoutes.rideModeName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _fade(state, RideModeScreen(roomCode: code));
        },
      ),
      GoRoute(
        path: AppRoutes.planning,
        name: AppRoutes.planningName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _fade(state, PlanningScreen(roomCode: code));
        },
      ),
      GoRoute(
        path: AppRoutes.results,
        name: AppRoutes.resultsName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _fade(state, RideResultsScreen(roomCode: code));
        },
      ),
      GoRoute(
        path: AppRoutes.initializing,
        name: AppRoutes.initializingName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _fade(state, RideInitializationScreen(roomCode: code));
        },
      ),
      GoRoute(
        path: AppRoutes.freeRide,
        name: AppRoutes.freeRideName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _fade(state, RideMapScreen(roomCode: code));
        },
      ),
      GoRoute(
        path: AppRoutes.ride,
        name: AppRoutes.rideName,
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId'] ?? '';
          return _fade(state, RideScreen(rideId: rideId));
        },
      ),
      GoRoute(
        path: AppRoutes.card,
        name: AppRoutes.cardName,
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId'] ?? '';
          return _fade(state, RideCardScreen(rideId: rideId));
        },
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authStateChangesProvider);
      final location = state.matchedLocation;
      final atSplash = location == AppRoutes.splash;
      final atOnboarding = location == AppRoutes.onboarding;

      return authState.when(
        // Auth not yet resolved on cold start: hold on the splash. This is
        // distinct from a resolved "signed out", so returning users never flash
        // the onboarding screen before their session restores.
        loading: () => atSplash ? null : AppRoutes.splash,
        // On error, fall back to onboarding so the user can retry sign-in.
        error: (error, stack) => atOnboarding ? null : AppRoutes.onboarding,
        data: (user) {
          final signedIn = user != null;
          if (!signedIn) {
            // No session: the only valid destination is onboarding.
            return atOnboarding ? null : AppRoutes.onboarding;
          }
          // Signed in: keep users out of splash/onboarding; send them home.
          if (atSplash || atOnboarding) {
            return AppRoutes.home;
          }
          return null;
        },
      );
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});

/// Bridges [authStateChangesProvider] to a [Listenable] so [GoRouter] re-runs
/// its redirect whenever the authentication state changes.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(this._ref) {
    _subscription = _ref.listen<AsyncValue<Object?>>(
      authStateChangesProvider,
      (previous, next) => notifyListeners(),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<Object?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// Builds a page with a calm fade transition, matching the app's motion system.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      );
    },
  );
}
