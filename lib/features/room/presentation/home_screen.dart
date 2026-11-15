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
import '../../../core/errors/result.dart';
import '../../../core/feedback/app_haptics.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../history/presentation/widgets/previous_rides_section.dart';
import 'ride_launcher.dart';
import 'widgets/solo_ride_card.dart';

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
                      child: SoloRideCard(
                        onTap: () => context.push(AppRoutes.solo),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FadeSlideIn(
                      delay: _stagger * 3,
                      child: const _CreateRideButton(),
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

/// Creates a group ride and opens its lobby. The host names the ride after it,
/// so there is nothing to fill in first.
class _CreateRideButton extends ConsumerStatefulWidget {
  const _CreateRideButton();

  @override
  ConsumerState<_CreateRideButton> createState() => _CreateRideButtonState();
}

class _CreateRideButtonState extends ConsumerState<_CreateRideButton> {
  bool _creating = false;

  /// The ride was created; the button shows a check until the lobby opens.
  bool _created = false;

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    final result = await ref.read(rideLauncherProvider).startGroupRide();
    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        AppHaptics.success();
        setState(() => _created = true);
        await Future<void>.delayed(AppMotion.successHold);
        if (!mounted) return;
        context.go(AppRoutes.lobbyPath(value.code));
      case Failed(:final failure):
        setState(() => _creating = false);
        showAppSnackBar(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Host Ride',
      icon: Icons.add_rounded,
      verticalPadding: HomeScreen._buttonPadding,
      isLoading: _creating,
      isSuccess: _created,
      onPressed: _create,
    );
  }
}