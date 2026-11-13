import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/rider_palette.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../../ride/domain/summary/ride_summary.dart';
import '../../domain/ride_details.dart';
import '../ride_mode_label.dart';

/// The colour a rider is drawn in.
Color riderColorOf(RiderRideSummary rider) =>
    RiderPalette.colorById(rider.colorId)?.color ?? AppColors.textPrimary;

/// The name shown for a rider: their own, else their colour's name.
String riderNameOf(RiderRideSummary rider) {
  final name = rider.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return RiderPalette.colorById(rider.colorId)?.label ?? 'Rider';
}

/// Title and time of the ride.
class RideTitleBlock extends StatelessWidget {
  const RideTitleBlock({super.key, required this.summary});

  final RideSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final started = DateTime.fromMillisecondsSinceEpoch(
      summary.group.startedAtMs,
    );
    final ended = DateTime.fromMillisecondsSinceEpoch(summary.group.endedAtMs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.roomName,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: AppTypeScale.headline,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${RideFormat.date(ended)}  ·  '
          '${RideFormat.time(started)} to ${RideFormat.time(ended)}  ·  '
          '${summary.mode.label}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// The four numbers that matter most, large, then a quiet line of the rest.
class RideHeroStats extends StatelessWidget {
  const RideHeroStats({
    super.key,
    required this.group,
    this.progress = const AlwaysStoppedAnimation<double>(1),
  });

  final GroupRideSummary group;

  /// How far the numbers have counted up, 0 to 1.
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _HeroStat(
                label: 'DISTANCE',
                progress: progress,
                text: (t) =>
                    _split(RideFormat.distance(group.totalDistanceMeters * t)),
              ),
            ),
            Expanded(
              child: _HeroStat(
                label: 'DURATION',
                progress: progress,
                text: (t) => (
                  RideFormat.duration(
                    Duration(milliseconds: (group.durationMs * t).round()),
                  ),
                  '',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _HeroStat(
                label: 'AVG SPEED',
                progress: progress,
                text: (t) =>
                    _split(RideFormat.speed(group.averageSpeedMps * t)),
              ),
            ),
            Expanded(
              child: _HeroStat(
                label: 'TOP SPEED',
                progress: progress,
                accent: AppColors.primary,
                text: (t) => _split(RideFormat.speed(group.maxSpeedMps * t)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '${group.riderCount} ${group.riderCount == 1 ? 'rider' : 'riders'}'
          '  ·  longest ${RideFormat.distance(group.longestDistanceMeters)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  /// "12.3 km" into ("12.3", "km").
  static (String, String) _split(String text) {
    final i = text.lastIndexOf(' ');
    return i < 0 ? (text, '') : (text.substring(0, i), text.substring(i + 1));
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.progress,
    required this.text,
    this.accent = AppColors.textPrimary,
  });

  final String label;
  final Animation<double> progress;

  /// The number and its unit when the count has reached the given fraction.
  final (String, String) Function(double t) text;
  final Color accent;

  static const double _valueSize = 34;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: AppSpacing.xs),
        // Only the number rebuilds as it counts up.
        AnimatedBuilder(
          animation: progress,
          builder: (context, _) {
            final (value, unit) = text(progress.value);
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: AppTypography.stat(
                      fontSize: _valueSize,
                      color: accent,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      unit,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A titled block of the details screen.
class DetailsSection extends StatelessWidget {
  const DetailsSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel(title)),
            if (trailing != null)
              Text(
                trailing!,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.textTertiary),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

/// A card-like group of rows, hairline separated.
class _RowsCard extends StatelessWidget {
  const _RowsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Everyone who rode. Tapping a rider highlights their route on the map;
/// tapping them again shows everyone.
class RiderListCard extends StatelessWidget {
  const RiderListCard({
    super.key,
    required this.riders,
    required this.myUid,
    required this.selectedUid,
    required this.onSelect,
  });

  final List<RiderRideSummary> riders;
  final String? myUid;
  final String? selectedUid;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return _RowsCard(
      children: [
        for (final rider in riders)
          _RiderRow(
            leading: _ColorDot(
              color: riderColorOf(rider),
              ringed: rider.uid == selectedUid,
            ),
            rider: rider,
            myUid: myUid,
            value: RideFormat.distance(rider.distanceMeters),
            detail: RideFormat.duration(rider.movingTime),
            selected: rider.uid == selectedUid,
            dimmed: selectedUid != null && rider.uid != selectedUid,
            onTap: () => onSelect(rider.uid == selectedUid ? null : rider.uid),
          ),
      ],
    );
  }
}

/// Riders ordered by a metric the viewer can switch.
class RankingCard extends StatefulWidget {
  const RankingCard({super.key, required this.riders, required this.myUid});

  final List<RiderRideSummary> riders;
  final String? myUid;

  @override
  State<RankingCard> createState() => _RankingCardState();
}

class _RankingCardState extends State<RankingCard> {
  RankMetric _metric = RankMetric.distance;

  String _format(RiderRideSummary rider) => switch (_metric) {
    RankMetric.distance => RideFormat.distance(rider.distanceMeters),
    RankMetric.topSpeed => RideFormat.speed(rider.maxSpeedMps),
    RankMetric.averageSpeed => RideFormat.speed(rider.averageSpeedMps),
  };

  @override
  Widget build(BuildContext context) {
    final ranked = RideRankings.rank(widget.riders, _metric);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SegmentedTabs<RankMetric>(
          values: RankMetric.values,
          selected: _metric,
          labelOf: (m) => m.label,
          onChanged: (m) => setState(() => _metric = m),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: AppMotion.normal,
          switchInCurve: AppMotion.curve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_metric),
            child: _RowsCard(
              children: [
                for (final entry in ranked.indexed)
                  _RiderRow(
                    leading: _Position(entry.$1 + 1),
                    rider: entry.$2,
                    myUid: widget.myUid,
                    value: _format(entry.$2),
                    dotColor: riderColorOf(entry.$2),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A row of options with a pill that slides to the chosen one.
class _SegmentedTabs<T> extends StatelessWidget {
  const _SegmentedTabs({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  static const double _height = 40;
  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected);
    return Container(
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                left: width * index,
                width: width,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in values)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(value),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AppMotion.normal,
                            style: Theme.of(context).textTheme.labelLarge!
                                .copyWith(
                                  color: value == selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                            child: Text(labelOf(value)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Riders in the order they finished, with the gap behind the first.
class FinishOrderCard extends StatelessWidget {
  const FinishOrderCard({super.key, required this.riders, required this.myUid});

  final List<RiderRideSummary> riders;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    final ordered = RideRankings.finishOrder(riders);
    final firstEnd = ordered.isEmpty ? null : ordered.first.endedAtMs;
    return _RowsCard(
      children: [
        for (final entry in ordered.indexed)
          _RiderRow(
            leading: _Position(entry.$1 + 1),
            rider: entry.$2,
            myUid: myUid,
            dotColor: riderColorOf(entry.$2),
            value: _finishLabel(entry.$2, firstEnd),
          ),
      ],
    );
  }

  static String _finishLabel(RiderRideSummary rider, int? firstEnd) {
    final end = rider.endedAtMs;
    if (!rider.finished || end == null) return 'No final data';
    if (firstEnd == null || end == firstEnd) return 'First';
    return RideFormat.gap(Duration(milliseconds: end - firstEnd));
  }
}

/// Features that are planned but not available yet.
class ComingSoonCard extends StatelessWidget {
  const ComingSoonCard({super.key});

  static const List<(IconData, String)> _items = [
    (Icons.file_download_rounded, 'GPX export'),
    (Icons.wb_sunny_rounded, 'Weather'),
    (Icons.notes_rounded, 'Notes'),
    (Icons.photo_library_rounded, 'Photos'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _RowsCard(
      children: [
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  item.$1,
                  size: AppIconSize.medium,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.$2,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  'Soon',
                  style: theme.textTheme.labelMedium?.copyWith(
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

class _RiderRow extends StatelessWidget {
  const _RiderRow({
    required this.leading,
    required this.rider,
    required this.myUid,
    required this.value,
    this.detail,
    this.dotColor,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
  });

  final Widget leading;
  final RiderRideSummary rider;
  final String? myUid;
  final String value;
  final String? detail;

  /// When set, a colour dot is shown beside the name.
  final Color? dotColor;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = rider.uid == myUid;
    final tags = [if (isMe) 'You', if (rider.isHost) 'Host'].join(' · ');
    final row = AnimatedContainer(
      duration: AppMotion.normal,
      color: selected
          ? riderColorOf(rider).withValues(alpha: 0.10)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: AnimatedOpacity(
        duration: AppMotion.normal,
        opacity: dimmed ? 0.45 : 1,
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSpacing.md),
            if (dotColor != null) ...[
              _ColorDot(color: dotColor!),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    riderNameOf(rider),
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tags.isNotEmpty)
                    Text(
                      tags,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: AppTypography.stat(fontSize: AppTypeScale.statSmall),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, this.ringed = false});

  final Color color;
  final bool ringed;

  static const double _size = 12;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: ringed
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}

class _Position extends StatelessWidget {
  const _Position(this.position);

  final int position;

  static const double _width = 22;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: Text(
        '$position',
        style: AppTypography.stat(
          fontSize: AppTypeScale.statSmall,
          color: position == 1 ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
