import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/ride_loader.dart';
import '../../../core/widgets/section_label.dart';
import '../../auth/domain/user_profile.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../ride/domain/live/ride_format.dart';
import '../domain/rider_stats.dart';
import 'providers/profile_providers.dart';
import 'widgets/profile_avatar.dart';

/// The rider's own page: who they are, what they have ridden, and whether
/// everything is safely in the cloud. Edit Profile, Sync Now and Sign Out
/// live here.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const double _avatarSize = 72;
  static const Duration _stagger = AppMotion.stagger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final email =
        profile?.email ??
        ref.watch(authStateChangesProvider.select((a) => a.value?.email));
    final stats = ref.watch(riderStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          FadeSlideIn(
            child: _Header(
              profile: profile,
              email: email,
              avatarSize: _avatarSize,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const FadeSlideIn(delay: _stagger, child: _SyncPill()),
          const SizedBox(height: AppSpacing.xxl),
          FadeSlideIn(
            delay: _stagger * 2,
            child: _StatsSection(stats: stats.value),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FadeSlideIn(
            delay: _stagger * 3,
            child: AppButton(
              label: 'Edit Profile',
              icon: Icons.edit_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.push(AppRoutes.profileEdit),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(delay: _stagger * 3, child: const _SyncNowButton()),
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(delay: _stagger * 4, child: const _SignOutButton()),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.email,
    required this.avatarSize,
  });

  final UserProfile? profile;
  final String? email;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final since = profile?.memberSince;
    return Row(
      children: [
        ProfileAvatar(
          size: avatarSize,
          photoUrl: profile?.photoUrl,
          riderName: profile?.riderName,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.riderName ?? 'Rider',
                style: theme.textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (email != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  email!,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (since != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Member since ${RideFormat.date(since)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "✓ Synced", "Syncing..." or "Offline".
class _SyncPill extends ConsumerWidget {
  const _SyncPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(cloudSyncStatusProvider);
    final theme = Theme.of(context);
    final (Widget icon, String label, Color color) = switch (status) {
      CloudSyncStatus.synced => (
        const Icon(
          Icons.check_rounded,
          size: 16,
          color: AppColors.success,
        ),
        'Synced',
        AppColors.textPrimary,
      ),
      CloudSyncStatus.syncing => (
        const RideLoader(size: 16),
        'Syncing...',
        AppColors.textPrimary,
      ),
      CloudSyncStatus.offline => (
        const Icon(
          Icons.cloud_off_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        'Offline',
        AppColors.textSecondary,
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.exit,
        child: Container(
          key: ValueKey(status),
          padding: AppSpacing.pill,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Semantics(
            label: 'Cloud sync: $label',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  /// `null` while loading.
  final RiderStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    String v(String Function(RiderStats s) read) => s == null ? '—' : read(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('TOTALS'),
        const SizedBox(height: AppSpacing.md),
        _StatGrid(
          items: [
            ('Rides', v((s) => '${s.totalRides}')),
            ('Distance', v((s) => RideFormat.distance(s.totalDistanceMeters))),
            ('Ride time', v((s) => formatRideTime(s.totalRideTime))),
          ],
          columns: 3,
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('RECORDS'),
        const SizedBox(height: AppSpacing.md),
        _StatGrid(
          items: [
            ('Highest speed', v((s) => RideFormat.speed(s.highestSpeedMps))),
            ('Longest ride', v((s) => RideFormat.distance(s.longestRideMeters))),
            (
              'Average distance',
              v((s) => RideFormat.distance(s.averageDistanceMeters)),
            ),
            ('Average speed', v((s) => RideFormat.speed(s.averageSpeedMps))),
          ],
          columns: 2,
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('RIDES BY TYPE'),
        const SizedBox(height: AppSpacing.md),
        _StatGrid(
          items: [
            ('Guided', v((s) => '${s.guidedRides}')),
            ('Free roam', v((s) => '${s.freeRoamRides}')),
            ('Group', v((s) => '${s.groupRides}')),
            ('Solo', v((s) => '${s.soloRides}')),
          ],
          columns: 2,
        ),
      ],
    );
  }
}

/// "45 min", "3 h 20 min", or "0 min".
String formatRideTime(Duration value) {
  final minutes = value.inMinutes;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items, required this.columns});

  final List<(String label, String value)> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <List<(String, String)>>[
      for (var i = 0; i < items.length; i += columns)
        items.sublist(i, (i + columns).clamp(0, items.length)),
    ];
    return AppCard(
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++)
                  Expanded(
                    child: c < rows[r].length
                        ? _Stat(label: rows[r][c].$1, value: rows[r][c].$2)
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: AppMotion.normal,
            child: Text(
              value,
              key: ValueKey(value),
              style: theme.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SyncNowButton extends ConsumerWidget {
  const _SyncNowButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(syncNowProvider);
    return AppButton(
      label: 'Sync Now',
      icon: Icons.sync_rounded,
      variant: AppButtonVariant.secondary,
      isLoading: syncing,
      onPressed: () async {
        final reached = await ref.read(syncNowProvider.notifier).run();
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          reached
              ? 'Everything is up to date.'
              : 'You are offline. Changes upload when you are back online.',
        );
      },
    );
  }
}

class _SignOutButton extends ConsumerStatefulWidget {
  const _SignOutButton();

  @override
  ConsumerState<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<_SignOutButton> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => const AppDialog(
        title: 'Sign out?',
        message:
            'Your rides and settings stay in your account. Sign in with '
            'Google again to get them back on any phone.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Sign Out',
        destructive: true,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    final result = await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    // On success the router takes the rider to the sign-in screen.
    if (result case Failed(:final failure)) {
      setState(() => _signingOut = false);
      showAppSnackBar(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Sign Out',
      icon: Icons.logout_rounded,
      variant: AppButtonVariant.destructive,
      isLoading: _signingOut,
      onPressed: _signOut,
    );
  }
}
