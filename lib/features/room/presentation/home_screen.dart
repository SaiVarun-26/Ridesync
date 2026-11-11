import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/glow_button.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../history/presentation/widgets/previous_rides_section.dart';

/// Landing screen: a calm headline, the two ways into a ride, and the rider's
/// previous rides underneath.
///
/// Whitespace does the work here. A small mark, a greeting, one large
/// headline, two generous buttons, a hairline, and the history. A single soft
/// glow behind the headline gives it depth. Each block fades in a beat after
/// the one above it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const Duration _stagger = Duration(milliseconds: 70);
  static const double _wordmarkSpacing = 2.6;
  static const double _headlineSize = 40;
  static const double _buttonPadding = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(
      authStateChangesProvider.select((a) => a.value?.displayName),
    );
    final greeting =
        name != null && name.trim().isNotEmpty ? 'Hey, ${name.trim()}' : null;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -140,
            left: -100,
            child: IgnorePointer(child: _Glow()),
          ),
          SafeArea(
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
                      FadeSlideIn(
                        child: Row(
                          children: [
                            const BrandMark(size: 22),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'RIDESYNC',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: _wordmarkSpacing,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      if (greeting != null)
                        FadeSlideIn(
                          delay: _stagger,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
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
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Ride together.\n'),
                              TextSpan(
                                text: 'Track together.',
                                style: TextStyle(
                                  color: AppColors.neonGreen.withValues(
                                    alpha: 0.95,
                                  ),
                                ),
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
                        child: GlowButton(
                          label: 'Create Ride',
                          icon: Icons.add_rounded,
                          accent: AppColors.neonGreen,
                          foreground: AppColors.background,
                          verticalPadding: _buttonPadding,
                          onPressed: () => context.push(AppRoutes.create),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FadeSlideIn(
                        delay: _stagger * 4,
                        child: GlowButton(
                          label: 'Join Ride',
                          icon: Icons.group_add_rounded,
                          variant: GlowButtonVariant.secondary,
                          verticalPadding: _buttonPadding,
                          onPressed: () => context.push(AppRoutes.join),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      const Divider(height: 1, color: AppColors.divider),
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
        ],
      ),
    );
  }
}

/// A single, very soft green glow behind the headline. Static, so it costs
/// nothing after the first frame.
class _Glow extends StatelessWidget {
  const _Glow();

  static const double _diameter = 420;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.neonGreen.withValues(alpha: 0.10),
              AppColors.neonGreen.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
