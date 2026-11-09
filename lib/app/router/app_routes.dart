import 'package:flutter/foundation.dart';

/// Canonical route paths and names for the app's navigation graph.
///
/// Paths are used for `go`/`push`; names are used for type-safe named
/// navigation and for building deep links.
@immutable
abstract final class AppRoutes {
  // Paths
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String create = '/create';
  static const String join = '/join';

  /// `/lobby/:code`
  static const String lobby = '/lobby/:code';

  /// `/ride-mode/:code`
  static const String rideMode = '/ride-mode/:code';

  /// `/planning/:code`
  static const String planning = '/planning/:code';

  /// `/initializing/:code`
  static const String initializing = '/initializing/:code';

  /// `/free-ride/:code`
  static const String freeRide = '/free-ride/:code';

  /// `/results/:code`
  static const String results = '/results/:code';

  /// `/ride/:rideId`
  static const String ride = '/ride/:rideId';

  /// `/card/:rideId`
  static const String card = '/card/:rideId';

  // Names
  static const String splashName = 'splash';
  static const String onboardingName = 'onboarding';
  static const String homeName = 'home';
  static const String createName = 'create';
  static const String joinName = 'join';
  static const String lobbyName = 'lobby';
  static const String rideModeName = 'rideMode';
  static const String planningName = 'planning';
  static const String initializingName = 'initializing';
  static const String freeRideName = 'freeRide';
  static const String resultsName = 'results';
  static const String rideName = 'ride';
  static const String cardName = 'card';

  /// Builds the concrete lobby path for a given [code].
  static String lobbyPath(String code) => '/lobby/$code';

  /// Builds the concrete ride-mode selection path for room [code].
  static String rideModePath(String code) => '/ride-mode/$code';

  /// Builds the concrete guided-ride planning path for room [code].
  static String planningPath(String code) => '/planning/$code';

  /// Builds the concrete ride-initialization path for room [code].
  static String initializingPath(String code) => '/initializing/$code';

  /// Builds the concrete ride-results path for room [code].
  static String resultsPath(String code) => '/results/$code';

  /// Builds the concrete free-ride path for room [code].
  static String freeRidePath(String code) => '/free-ride/$code';

  /// Builds the concrete ride path for a given [rideId].
  static String ridePath(String rideId) => '/ride/$rideId';

  /// Builds the concrete card path for a given [rideId].
  static String cardPath(String rideId) => '/card/$rideId';

  const AppRoutes._();
}
