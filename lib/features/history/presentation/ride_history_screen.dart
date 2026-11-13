import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/ride_loader.dart';
import '../domain/ride_history_entry.dart';
import 'open_ride_details.dart';
import 'providers/ride_history_providers.dart';
import 'widgets/ride_history_card.dart';
import 'widgets/ride_history_skeleton.dart';

/// Every previous ride, newest first. Older rides load as the rider scrolls.
class RideHistoryScreen extends ConsumerStatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  final ScrollController _scroll = ScrollController();

  /// How close to the end (in pixels) the next page starts loading.
  static const double _loadAhead = 400;

  /// Cards that fade in one after another when the list first appears; cards
  /// further down, and ones loaded later, just appear with the scroll.
  static const int _staggered = 6;
  static const Duration _stagger = AppMotion.stagger;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < _loadAhead) {
      ref.read(rideHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(rideHistoryProvider);
    final entries = history.entries;

    return Scaffold(
      appBar: AppBar(title: const Text('Previous Rides')),
      body: Stack(
        children: [
          Positioned.fill(child: _refreshable(entries, history)),
          // Pull-to-refresh shows the RideSync loader, not the stock spinner.
          Positioned(
            top: AppSpacing.md,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                switchInCurve: AppMotion.curve,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: _refreshing
                    ? const Center(
                        key: ValueKey('refreshing'),
                        child: RideLoader(),
                      )
                    : const SizedBox.shrink(key: ValueKey('idle')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// True from the moment a pull is released until the refresh settles.
  bool _refreshing = false;

  void _onRefreshStatus(RefreshIndicatorStatus? status) {
    final active = status == RefreshIndicatorStatus.refresh;
    if (active != _refreshing && mounted) setState(() => _refreshing = active);
  }

  Widget _refreshable(
    List<RideHistoryEntry> entries,
    RideHistoryState history,
  ) {
    return RefreshIndicator.noSpinner(
      onRefresh: () => ref.read(rideHistoryProvider.notifier).refresh(),
      onStatusChange: _onRefreshStatus,
      child: AnimatedSwitcher(
        duration: AppMotion.normal,
        child: entries.isEmpty
            ? _EmptyOrLoading(key: const ValueKey('empty'), history: history)
            : ListView.separated(
                key: const ValueKey('list'),
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.xl),
                itemCount: entries.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  if (index == entries.length) {
                    return _Footer(history: history);
                  }
                  final entry = entries[index];
                  final card = RideHistoryCard(
                    entry: entry,
                    onTap: (origin) => openRideDetails(
                      context,
                      ref,
                      code: entry.code,
                      origin: origin,
                    ),
                  );
                  return KeyedSubtree(
                    key: ValueKey(entry.code),
                    child: index < _staggered
                        ? FadeSlideIn(delay: _stagger * index, child: card)
                        : card,
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyOrLoading extends StatelessWidget {
  const _EmptyOrLoading({super.key, required this.history});

  final RideHistoryState history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (history.isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: const [
          RideHistorySkeleton(),
          SizedBox(height: AppSpacing.md),
          RideHistorySkeleton(),
          SizedBox(height: AppSpacing.md),
          RideHistorySkeleton(),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        FadeSlideIn(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              const Icon(
                Icons.route_rounded,
                size: AppIconSize.hero,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                history.error == null ? 'No rides yet' : "Couldn't load rides",
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                history.error ?? 'Rides you finish will show up here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.history});

  final RideHistoryState history;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: AppColors.textTertiary);
    if (history.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: RideLoader()),
      );
    }
    final message =
        history.error ??
        (history.fromCache ? 'Offline. Showing saved rides.' : null);
    if (message == null) return const SizedBox(height: AppSpacing.xl);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(child: Text(message, style: style)),
    );
  }
}
