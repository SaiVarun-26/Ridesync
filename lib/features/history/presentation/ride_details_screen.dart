import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/ride_loader.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../insights/presentation/providers/insights_providers.dart';
import '../../insights/presentation/share/ride_share_sheet.dart';
import '../../naming/presentation/rename_ride_flow.dart';
import '../domain/ride_details.dart';
import 'providers/ride_details_providers.dart';
import 'story/ride_story_view.dart';

/// A finished ride from history, told as the same story of cards as the
/// results screen: the solo journey, or the group's ride with its replay,
/// standings and moments. The name can be changed from the overview.
class RideDetailsScreen extends ConsumerWidget {
  const RideDetailsScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(rideDetailsProvider(roomCode));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              onShare: details.hasValue
                  ? () => showRideShareSheet(context, code: roomCode)
                  : null,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.slow,
                switchInCurve: AppMotion.curve,
                switchOutCurve: AppMotion.exit,
                child: details.when(
                  loading: () => const Center(
                    key: ValueKey('loading'),
                    child: RideLoader(size: RideLoader.hero),
                  ),
                  error: (error, _) => _Failed(
                    key: const ValueKey('error'),
                    message: error is Failure
                        ? error.message
                        : 'Could not load this ride.',
                    onRetry: () =>
                        ref.invalidate(rideDetailsProvider(roomCode)),
                  ),
                  data: (data) => _Content(key: const ValueKey('ride'), details: data),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({super.key, required this.details});

  final RideDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = details.summary;
    final code = summary.roomCode;
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    // Built once, in the background; its cards join as it arrives.
    final recap = ref.watch(rideRecapProvider(code)).value;
    return Column(
      children: [
        if (details.fromCache)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              'Offline. Showing the saved copy of this ride.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        Expanded(
          child: RideStoryView(
            details: details,
            myUid: myUid,
            recap: recap,
            onRename: () => renameRideFlow(
              context,
              ref,
              code: code,
              currentName: summary.roomName,
            ),
            onShare: () => showRideShareSheet(context, code: code),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onShare});

  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          AppIconButton(
            icon: Icons.ios_share_rounded,
            tooltip: 'Share ride',
            color: AppColors.textSecondary,
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Try again', expand: false, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
