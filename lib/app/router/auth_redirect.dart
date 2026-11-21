import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/user_profile.dart';
import 'app_routes.dart';

/// Where the router sends the rider for their session, or `null` to stay at
/// [location].
///
/// - Session not known yet: hold on the splash.
/// - Signed out: the sign-in screen.
/// - A legacy anonymous session: the sign-in screen too (continuing with
///   Google keeps their rides), except during a ride, which is never
///   interrupted.
/// - Signed in with Google but no rider name yet: the rider-name screen.
/// - Otherwise: out of splash, sign-in and rider-name, into Home.
String? authRedirect({
  required AsyncValue<AppUser?> auth,
  required AsyncValue<UserProfile?> profile,
  required String location,
}) {
  final atSplash = location == AppRoutes.splash;
  final atOnboarding = location == AppRoutes.onboarding;
  final atWelcome = location == AppRoutes.welcome;
  final inRide = isRideFlowLocation(location);

  if (auth.isLoading && !auth.hasValue) {
    return atSplash ? null : AppRoutes.splash;
  }
  if (auth.hasError && !auth.hasValue) {
    return atOnboarding ? null : AppRoutes.onboarding;
  }
  final user = auth.value;
  if (user == null) {
    return atOnboarding ? null : AppRoutes.onboarding;
  }
  if (user.isAnonymous) {
    if (inRide || atOnboarding) return null;
    return AppRoutes.onboarding;
  }

  final known = profile.value;
  final profileResolved =
      !profile.isLoading || (known != null && known.uid == user.uid);
  if (!profileResolved) {
    // Still loading this rider's profile: wait on the splash if they are at
    // an entry screen, otherwise stay put.
    return (atOnboarding || atWelcome) ? AppRoutes.splash : null;
  }
  if (profile.hasError && known == null) {
    // The profile could not be read (e.g. offline with nothing cached): let
    // them ride rather than lock them out.
    return (atSplash || atOnboarding || atWelcome) ? AppRoutes.home : null;
  }
  if (known == null || !known.hasRiderName) {
    if (inRide || atWelcome) return null;
    return AppRoutes.welcome;
  }
  if (atSplash || atOnboarding || atWelcome) return AppRoutes.home;
  return null;
}

/// Whether [location] is a screen of a ride in progress (lobby through
/// results), where a session change must not navigate away.
bool isRideFlowLocation(String location) {
  const prefixes = [
    '/lobby/',
    '/ride-mode/',
    '/planning/',
    '/initializing/',
    '/free-ride/',
    '/ride/',
    '/results/',
  ];
  return prefixes.any(location.startsWith);
}
