import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/fade_slide_in.dart';
import 'providers/auth_providers.dart';

/// The sign-in screen: one way in, "Continue with Google".
///
/// On success the session changes and the router moves the rider on (to the
/// rider-name screen the first time, else Home), so this screen never
/// navigates itself. Backing out of the account picker just leaves the rider
/// here; other failures show inline.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _isSubmitting = false;

  Future<void> _continue() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (!mounted) return;

    switch (result) {
      case Success<Object?>():
        // The router takes it from here once the session updates. Stay in
        // the loading state until this screen is replaced.
        break;
      case Failed(:final failure):
        setState(() => _isSubmitting = false);
        if (failure is! SignInCancelled) {
          showAppSnackBar(context, failure.message);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLegacy = ref.watch(
      authStateChangesProvider.select((a) => a.value?.isAnonymous ?? false),
    );
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const FadeSlideIn(child: BrandMark()),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: AppMotion.stagger,
                  child: Text('RideSync', style: theme.textTheme.displayMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: AppMotion.stagger * 2,
                  child: Text(
                    'Never lose your ride.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                FadeSlideIn(
                  delay: AppMotion.stagger * 3,
                  child: Text(
                    isLegacy
                        ? 'Sign in to keep your rides. Everything you have '
                              'ridden so far stays with you.'
                        : 'Sign in to keep your rides safe and pick them up '
                              'on any phone.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const Spacer(),
                FadeSlideIn(
                  delay: AppMotion.stagger * 4,
                  child: AppButton(
                    label: 'Continue with Google',
                    icon: Icons.login_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _continue,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
