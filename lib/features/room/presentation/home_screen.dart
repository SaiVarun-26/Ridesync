import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../history/presentation/widgets/previous_rides_section.dart';

/// Landing screen: the brand, a calm headline, the two ways into a ride, and
/// the rider's previous rides underneath.
///
/// Whitespace does the work here. The wordmark, a greeting, one large
/// headline, two generous buttons, a hairline, and the history, each fading in
/// a beat after the one above it, over the app's faint violet bloom.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const Duration _stagger = AppMotion.stagger;
  static const double _headlineSize = 40;
  static const double _buttonPadding = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(
      authStateChangesProvider.select((a) => a.value?.displayName),
    );
    final greeting = name != null && name.trim().isNotEmpty
        ? 'Hey, ${name.trim()}'
        : null;

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                sliver: SliverList.list(
                  children: [
                    const FadeSlideIn(child: BrandWordmark()),
                    const SizedBox(height: AppSpacing.xxxl),
                    if (greeting != null)
                      FadeSlideIn(
                        delay: _stagger,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            greeting,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    FadeSlideIn(
                      delay: _stagger * 2,
                      child: Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(text: 'Ride together.\n'),
                            TextSpan(
                              text: 'Track together.',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ],
                        ),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontSize: _headlineSize,
                          height: 1.08,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(
                      delay: _stagger * 3,
                      child: AppButton(
                        label: 'Create Ride',
                        icon: Icons.add_rounded,
                        verticalPadding: _buttonPadding,
                        onPressed: () => context.push(AppRoutes.create),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeSlideIn(
                      delay: _stagger * 4,
                      child: AppButton(
                        label: 'Join Ride',
                        icon: Icons.group_add_rounded,
                        variant: AppButtonVariant.secondary,
                        verticalPadding: _buttonPadding,
                        onPressed: () => context.push(AppRoutes.join),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: AppSpacing.xl),
                    FadeSlideIn(
                      delay: _stagger * 5,
                      child: const PreviousRidesSection(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
