import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../history/presentation/widgets/ride_details_sections.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../domain/achievements/achievement.dart';
import '../../domain/analysis/rider_analytics.dart';
import '../../domain/recap/ride_recap.dart';
import 'recap_sections.dart';

/// Every rider in finish order, each with their share of the group's
/// distance. Tap a rider to see their full breakdown: speeds, moving and
/// stopped time, consistency and any badge they earned.
class RiderAnalyticsList extends StatefulWidget {
  const RiderAnalyticsList({super.key, required this.recap});

  final RideRecap recap;

  @override
  State<RiderAnalyticsList> createState() => _RiderAnalyticsListState();
}

class _RiderAnalyticsListState extends State<RiderAnalyticsList> {
  /// The rider whose breakdown is open. This rider's opens first.
  late String? _open = widget.recap.myUid;

  @override
  Widget build(BuildContext context) {
    final recap = widget.recap;
    final riders = recap.riders;
    final solo = riders.length <= 1;
    return Column(
      children: [
        for (final (i, rider) in riders.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _RiderTile(
            analytics: rider,
            isMe: rider.uid == recap.myUid,
            showPosition: !solo,
            expanded: solo || _open == rider.uid,
            badge: recap.badgeFor(rider.uid),
            onTap: solo
                ? null
                : () => setState(
                    () => _open = _open == rider.uid ? null : rider.uid,
                  ),
          ),
        ],
      ],
    );
  }
}

class _RiderTile extends StatelessWidget {
  const _RiderTile({
    required this.analytics,
    required this.isMe,
    required this.showPosition,
    required this.expanded,
    required this.onTap,
    this.badge,
  });

  final RiderAnalytics analytics;
  final bool isMe;
  final bool showPosition;
  final bool expanded;
  final VoidCallback? onTap;
  final Achievement? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rider = analytics.rider;
    final color = riderColorOf(rider);
    final tile = AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: expanded
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showPosition) ...[
                SizedBox(
                  width: 28,
                  child: Text(
                    '#${analytics.finishPosition}',
                    style: AppTypography.stat(
                      fontSize: AppTypeScale.statSmall,
                      color: analytics.finishPosition == 1
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isMe ? '${analytics.name} (you)' : analytics.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                RideFormat.distance(rider.distanceMeters),
                style: AppTypography.stat(fontSize: AppTypeScale.statSmall),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: AppMotion.normal,
                  curve: AppMotion.curve,
                  child: const Icon(
                    Icons.expand_more_rounded,
                    size: AppIconSize.medium,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          if (showPosition) ...[
            const SizedBox(height: AppSpacing.sm),
            _ShareBar(share: analytics.contribution, color: color),
          ],
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.curve,
            alignment: Alignment.topCenter,
            child: expanded
                ? _Breakdown(analytics: analytics, badge: badge)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
    final labelled = Semantics(
      button: onTap != null,
      expanded: onTap == null ? null : expanded,
      child: tile,
    );
    if (onTap == null) return labelled;
    return PressableScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: labelled,
      ),
    );
  }
}

/// The rider's share of the group's distance, as a bar and a percentage.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.share, required this.color});

  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.border),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: share.clamp(0.0, 1.0)),
                    duration: AppMotion.entrance,
                    curve: AppMotion.curve,
                    builder: (context, value, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: ColoredBox(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${(share * 100).round()}% of group',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.analytics, this.badge});

  final RiderAnalytics analytics;
  final Achievement? badge;

  @override
  Widget build(BuildContext context) {
    final rider = analytics.rider;
    final consistency = analytics.consistency;
    final figures = <(String, String)>[
      ('AVG SPEED', RideFormat.speed(rider.averageSpeedMps)),
      ('TOP SPEED', RideFormat.speed(rider.maxSpeedMps)),
      ('MOVING', RideFormat.duration(analytics.movingTime)),
      ('STOPPED', RideFormat.duration(analytics.stoppedTime)),
      if (consistency != null) ('CONSISTENCY', '${consistency.round()}/100'),
      ('FINISH', '#${analytics.finishPosition}'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - AppSpacing.md * 2) / 3;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final (label, value) in figures)
                    SizedBox(
                      width: width,
                      child: _Figure(label: label, value: value),
                    ),
                ],
              );
            },
          ),
          if (badge != null) ...[
            const SizedBox(height: AppSpacing.md),
            AchievementChip(kind: badge!.kind),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            fontSize: AppTypeScale.micro,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTypography.stat(fontSize: AppTypeScale.statSmall),
          ),
        ),
      ],
    );
  }
}
