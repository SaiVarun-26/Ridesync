import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/rider_palette.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../insights/domain/achievements/achievement.dart';
import '../../../insights/presentation/widgets/recap_sections.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../domain/ride_history_entry.dart';
import 'route_thumbnail.dart';

/// One finished ride in a list, readable in a glance.
///
/// The route, drawn in this rider's colour, sits beside what the ride was
/// (its name and when) and, for a group ride, who rode and where this rider
/// finished. Beneath, the ride's figures, each shown once: distance and
/// duration, plus the top speed for a solo ride (a group ride's speeds live
/// in its standings). The best achievement, if any, is a small badge.
///
/// Pressing it lifts it; [onTap] is given the card's place on screen, which
/// the details page grows out of.
class RideHistoryCard extends StatefulWidget {
  const RideHistoryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onShare,
    this.onRename,
    this.onDelete,
  });

  final RideHistoryEntry entry;
  final ValueChanged<Rect> onTap;

  /// Shown in the card's ⋮ menu; no menu when both are `null`.
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  /// Opens the ride's share card straight from the list; no share button
  /// when `null`.
  final VoidCallback? onShare;

  /// Rides shorter than this have no route worth drawing.
  static const double stationaryMeters = 50;

  @override
  State<RideHistoryCard> createState() => _RideHistoryCardState();
}

class _RideHistoryCardState extends State<RideHistoryCard> {
  bool _lifted = false;

  static const double _thumb = 104;

  void _open(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    widget.onTap(box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.lg);
    final color = RiderPalette.colorById(entry.colorId)?.color;
    final achievement = entry.highlights?.achievementIds
        .map(AchievementKind.fromName)
        .nonNulls
        .firstOrNull;
    final ended = entry.endedAt;
    final started = DateTime.fromMillisecondsSinceEpoch(entry.startedAtMs);
    final group = entry.isGroup;

    return Semantics(
      button: true,
      label: [
        entry.roomName,
        RideFormat.date(ended),
        if (group) '${entry.riderCount} riders',
        if (group && entry.position != null)
          'you finished ${entry.position} of ${entry.riderCount}',
        RideFormat.distance(entry.distanceMeters),
        RideFormat.duration(entry.duration),
      ].join(', '),
      child: PressableScale(
        onPressedChanged: (down) => setState(() => _lifted = down),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: radius,
            border: Border.all(
              color: _lifted
                  ? (color ?? AppColors.primary).withValues(alpha: 0.7)
                  : AppColors.border,
            ),
            boxShadow: _lifted ? AppShadows.lifted : AppShadows.rest,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _open(context),
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RouteThumbnail(
                      points: entry.routePreview,
                      speedsMps: entry.previewSpeedsMps,
                      color: color,
                      size: _thumb,
                      // Too short to have a route: shown as staying put
                      // rather than as a route still on its way.
                      stationary:
                          entry.distanceMeters <
                          RideHistoryCard.stationaryMeters,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SizedBox(
                        height: _thumb,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  // A rename fades the new name in.
                                  child: AnimatedSwitcher(
                                    duration: AppMotion.normal,
                                    switchInCurve: AppMotion.curve,
                                    switchOutCurve: AppMotion.exit,
                                    layoutBuilder: (current, previous) => Stack(
                                      alignment: Alignment.topLeft,
                                      children: [...previous, ?current],
                                    ),
                                    child: Text(
                                      entry.roomName,
                                      key: ValueKey(entry.roomName),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                ),
                                if (widget.onShare != null)
                                  SizedBox(
                                    width: 32,
                                    height: 24,
                                    child: OverflowBox(
                                      maxWidth: AppIconButton.size,
                                      maxHeight: AppIconButton.size,
                                      child: AppIconButton(
                                        icon: Icons.ios_share_rounded,
                                        tooltip: 'Share ride',
                                        color: AppColors.textTertiary,
                                        onPressed: widget.onShare,
                                      ),
                                    ),
                                  ),
                                if (widget.onRename != null ||
                                    widget.onDelete != null)
                                  SizedBox(
                                    width: 32,
                                    height: 24,
                                    child: OverflowBox(
                                      maxWidth: AppIconButton.size,
                                      maxHeight: AppIconButton.size,
                                      child: _MoreMenu(
                                        onRename: widget.onRename,
                                        onDelete: widget.onDelete,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${RideFormat.date(ended)} · '
                              '${RideFormat.time(started)}',
                              maxLines: 1,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                if (group) ...[
                                  _Tag(
                                    icon: Icons.groups_rounded,
                                    label: '${entry.riderCount}',
                                  ),
                                  if (entry.position != null)
                                    _Tag(
                                      icon: entry.position == 1
                                          ? Icons.emoji_events_rounded
                                          : null,
                                      label: entry.position == 1
                                          ? '1st'
                                          : '#${entry.position} of '
                                                '${entry.riderCount}',
                                      highlight: entry.position == 1,
                                    ),
                                ] else
                                  const _Tag(
                                    icon: Icons.person_rounded,
                                    label: 'Solo',
                                  ),
                                if (achievement != null)
                                  AchievementChip(kind: achievement),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                _Figure(
                                  value: _distance(entry.distanceMeters),
                                  unit: entry.distanceMeters < 1000 ? 'm' : 'km',
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                _Figure(
                                  value: RideFormat.duration(entry.duration),
                                ),
                                if (!group && entry.maxSpeedMps > 0) ...[
                                  const SizedBox(width: AppSpacing.lg),
                                  _Figure(
                                    icon: Icons.bolt_rounded,
                                    value: '${(entry.maxSpeedMps * 3.6).round()}',
                                    unit: 'km/h',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _distance(double meters) => meters < 1000
      ? '${meters.round()}'
      : (meters / 1000).toStringAsFixed(meters >= 100000 ? 0 : 1);
}

enum _MoreAction { rename, delete }

/// The card's ⋮ menu: Rename Ride, Delete Ride.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.onRename, required this.onDelete});

  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    PopupMenuItem<_MoreAction> item(
      _MoreAction value,
      IconData icon,
      String label,
      Color color,
    ) => PopupMenuItem<_MoreAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.medium, color: color),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: color)),
        ],
      ),
    );
    return PopupMenuButton<_MoreAction>(
      tooltip: 'More',
      icon: const Icon(
        Icons.more_vert_rounded,
        size: AppIconSize.medium,
        color: AppColors.textTertiary,
      ),
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (action) => switch (action) {
        _MoreAction.rename => onRename?.call(),
        _MoreAction.delete => onDelete?.call(),
      },
      itemBuilder: (_) => [
        if (onRename != null)
          item(
            _MoreAction.rename,
            Icons.edit_rounded,
            'Rename Ride',
            AppColors.textPrimary,
          ),
        if (onDelete != null)
          item(
            _MoreAction.delete,
            Icons.delete_outline_rounded,
            'Delete Ride',
            AppColors.error,
          ),
      ],
    );
  }
}

/// A small pill: who rode, or where this rider finished.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon, this.highlight = false});

  final String label;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: highlight ? AppColors.textPrimary : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, this.unit, this.icon});

  final String value;
  final String? unit;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (icon != null)
              Icon(icon, size: AppIconSize.small, color: AppColors.textSecondary),
            Text(value, style: AppTypography.stat(fontSize: 20)),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
