import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

/// Shown while the authentication state is still resolving on cold start.
///
/// The router's redirect holds on this screen while
/// [authStateChangesProvider] is in its loading state, then routes to
/// onboarding (signed out) or home (signed in) once the session resolves. This
/// avoids flashing onboarding at returning users whose anonymous session is
/// being restored.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonGreen),
          ),
        ),
      ),
    );
  }
}
