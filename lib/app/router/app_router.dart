import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/history/presentation/providers/ride_transition_providers.dart';
import '../../features/history/presentation/ride_details_screen.dart';
import '../../features/history/presentation/ride_history_screen.dart';
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
import 'container_transform.dart';

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
        pageBuilder: (context, state) =>
            _page(state, const SplashScreen(), NavMotion.fadeThrough),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        pageBuilder: (context, state) =>
            _page(state, const OnboardingScreen(), NavMotion.fadeThrough),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        pageBuilder: (context, state) =>
            _page(state, const HomeScreen(), NavMotion.fadeThrough),
      ),
      GoRoute(
        path: AppRoutes.history,
        name: AppRoutes.historyName,
        pageBuilder: (context, state) =>
            _page(state, const RideHistoryScreen()),
      ),
      GoRoute(
        path: AppRoutes.historyDetails,
        name: AppRoutes.historyDetailsName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          // Grows out of the history card that was tapped.
          return containerTransformPage(
            state: state,
            origin: ref.read(rideTransitionOriginProvider),
            child: RideDetailsScreen(roomCode: code),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.create,
        name: AppRoutes.createName,
        pageBuilder: (context, state) => _page(state, const CreateRideScreen()),
      ),
      GoRoute(
        path: AppRoutes.join,
        name: AppRoutes.joinName,
        pageBuilder: (context, state) => _page(state, const JoinRideScreen()),
      ),
      GoRoute(
        path: AppRoutes.lobby,
        name: AppRoutes.lobbyName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _page(state, LobbyScreen(roomCode: code), NavMotion.flow);
        },
      ),
      GoRoute(
        path: AppRoutes.rideMode,
        name: AppRoutes.rideModeName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _page(state, RideModeScreen(roomCode: code), NavMotion.flow);
        },
      ),
      GoRoute(
        path: AppRoutes.planning,
        name: AppRoutes.planningName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _page(state, PlanningScreen(roomCode: code), NavMotion.flow);
        },
      ),
      GoRoute(
        path: AppRoutes.results,
        name: AppRoutes.resultsName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _page(
            state,
            RideResultsScreen(roomCode: code),
            NavMotion.flow,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.initializing,
        name: AppRoutes.initializingName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _page(
            state,
            RideInitializationScreen(roomCode: code),
            NavMotion.flow,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.freeRide,
        name: AppRoutes.freeRideName,
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _page(state, RideMapScreen(roomCode: code), NavMotion.flow);
        },
      ),
      GoRoute(
        path: AppRoutes.ride,
        name: AppRoutes.rideName,
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId'] ?? '';
          return _page(state, RideScreen(rideId: rideId), NavMotion.flow);
        },
      ),
      GoRoute(
        path: AppRoutes.card,
        name: AppRoutes.cardName,
        pageBuilder: (context, state) {
          final rideId = state.pathParameters['rideId'] ?? '';
          return _page(
            state,
            RideCardScreen(rideId: rideId),
            NavMotion.fadeThrough,
          );
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
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Route not found: ${state.uri}'))),
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

/// How a screen moves in and out. All of them use Material motion, over the
/// app's near-black so nothing ever flashes between screens.
enum NavMotion {
  /// Fade out, then fade in with a slight scale: for moving between
  /// top-level places (splash, onboarding, home).
  fadeThrough,

  /// Slide along the horizontal axis: for going one level deeper and back.
  sharedAxis,

  /// A plain fade through the page colour: for the stages of a ride, which
  /// follow each other rather than nest.
  flow,
}

/// Builds a page with the Material motion for [motion].
CustomTransitionPage<void> _page(
  GoRouterState state,
  Widget child, [
  NavMotion motion = NavMotion.sharedAxis,
]) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.slow,
    reverseTransitionDuration: AppMotion.normal,
    transitionsBuilder: (context, animation, secondaryAnimation, page) {
      return switch (motion) {
        NavMotion.fadeThrough => FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          fillColor: AppColors.background,
          child: page,
        ),
        NavMotion.sharedAxis => SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: AppColors.background,
          child: page,
        ),
        // The stages of a ride use the lightest transition there is, a fade
        // through the page colour, because the screens they open (a live map,
        // a results page) are heavy to build and a lighter transition leaves
        // them the frames to do it.
        NavMotion.flow => FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          fillColor: AppColors.background,
          child: page,
        ),
      };
    },
  );
}
