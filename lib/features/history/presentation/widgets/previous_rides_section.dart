import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/ride_history_providers.dart';
import '../open_ride_details.dart';
import 'ride_history_card.dart';
import 'ride_history_skeleton.dart';

/// The "Previous Rides" area of the landing page: the latest few rides and a
/// way to see them all.
///
/// Reads the shared history once; it never opens a listener of its own.
class PreviousRidesSection extends ConsumerWidget {
  const PreviousRidesSection({super.key});

  /// How many rides the landing page previews.
  static const int previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(rideHistoryProvider);
    final entries = history.entries;
    final canViewAll = entries.length > previewCount || history.hasMore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Previous Rides', style: theme.textTheme.titleMedium),
            ),
            if (canViewAll)
              TextButton(
                onPressed: () => context.push(AppRoutes.history),
                child: const Text('View all'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _body(context, ref, history),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, RideHistoryState history) {
    final theme = Theme.of(context);
    final entries = history.entries;

    if (entries.isEmpty && history.isLoading) {
      return const Column(
        key: ValueKey('loading'),
        children: [
          RideHistorySkeleton(),
          SizedBox(height: AppSpacing.md),
          RideHistorySkeleton(),
        ],
      );
    }

    if (entries.isEmpty) {
      final failed = history.error != null;
      return Container(
        key: const ValueKey('empty'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card + 4),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.route_outlined,
              color: AppColors.textTertiary,
              size: 30,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              failed ? "Couldn't load your rides" : 'No rides yet',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              failed ? history.error! : 'Rides you finish will show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            if (failed)
              TextButton(
                onPressed: () =>
                    ref.read(rideHistoryProvider.notifier).refresh(),
                child: const Text('Try again'),
              ),
          ],
        ),
      );
    }

    return Column(
      key: const ValueKey('list'),
      children: [
        if (history.fromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Offline. Showing saved rides.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        for (final entry in entries.take(previewCount))
          Padding(
            key: ValueKey(entry.code),
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: RideHistoryCard(
              entry: entry,
              onTap: (origin) => openRideDetails(
                context,
                ref,
                code: entry.code,
                origin: origin,
              ),
            ),
          ),
      ],
    );
  }
}
