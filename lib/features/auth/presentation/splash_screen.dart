import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/fade_slide_in.dart';

/// Shown while the authentication state is still resolving on cold start.
///
/// The router's redirect holds on this screen while
/// [authStateChangesProvider] is in its loading state, then routes to
/// onboarding (signed out) or home (signed in) once the session resolves. This
/// avoids flashing onboarding at returning users whose anonymous session is
/// being restored.
///
/// It continues straight from the native launch screen (same near-black), so
/// there is no flash between the two: the mark settles in, breathing, with
/// the name beneath it.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AmbientBackground(
        alignment: Alignment.center,
        child: Center(
          child: FadeScaleIn(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(breathing: true),
                const SizedBox(height: AppSpacing.xl),
                Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: 'Ride'),
                      TextSpan(
                        text: 'Sync',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
