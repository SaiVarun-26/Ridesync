import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../insights/domain/achievements/achievement.dart';
import '../../../insights/domain/score/ride_score.dart';
import '../../../insights/domain/weather/weather_snapshot.dart';
import '../../../insights/presentation/widgets/insight_visuals.dart';
import '../../../insights/presentation/widgets/recap_sections.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../domain/recap_highlights.dart';
import '../../domain/ride_history_entry.dart';
import '../ride_mode_label.dart';
import 'route_thumbnail.dart';

/// One finished ride in a list: a miniature of its route beside its name,
/// date and mode, its recap (sentence, score, weather and best achievement)
/// once worked out, with the ride's numbers beneath. A share button opens
/// the ride's card without opening the ride.
///
/// A translucent violet-tinted surface with a faint sheen and a hairline
/// border. Pressing it lifts it: it scales in a touch while its shadow deepens
/// and its border brightens. [onTap] is given the card's place on screen,
/// which the details screen grows out of.
class RideHistoryCard extends StatefulWidget {
  const RideHistoryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onShare,
  });

  final RideHistoryEntry entry;
  final ValueChanged<Rect> onTap;

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
    return PressableScale(
      onPressedChanged: (down) => setState(() => _lifted = down),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: _lifted
                ? AppColors.primary.withValues(alpha: 0.7)
                : AppColors.border,
          ),
          // Very large and very faint: only enough to lift the card off the
          // page. Deepens a little while pressed.
          boxShadow: _lifted ? AppShadows.lifted : AppShadows.rest,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      RouteThumbnail(
                        points: entry.routePreview,
                        speedsMps: entry.previewSpeedsMps,
                        // Too short to have a route: shown as staying put
                        // rather than as a route still on its way.
                        stationary:
                            entry.distanceMeters <
                            RideHistoryCard.stationaryMeters,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.roomName,
                              style: theme.textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              RideFormat.date(entry.endedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _ModeChip(label: entry.mode.label),
                          ],
                        ),
                      ),
                      if (widget.onShare != null)
                        AppIconButton(
                          icon: Icons.ios_share_rounded,
                          tooltip: 'Share ride',
                          color: AppColors.textSecondary,
                          onPressed: widget.onShare,
                        ),
                    ],
                  ),
                  // The recap, once it has been worked out: its sentence and
                  // score, the weather, and the best achievement.
                  AnimatedSize(
                    duration: AppMotion.slow,
                    curve: AppMotion.curve,
                    alignment: Alignment.topCenter,
                    child: entry.highlights == null
                        ? const SizedBox(width: double.infinity)
                        : FadeSlideIn(
                            child: _Highlights(highlights: entry.highlights!),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          _Figure(
                            value: RideFormat.distance(entry.distanceMeters),
                            label: 'DISTANCE',
                          ),
                          _Figure(
                            value: RideFormat.duration(entry.duration),
                            label: 'TIME',
                          ),
                          _Figure(
                            value: _speed(entry.averageSpeedMps),
                            unit: 'km/h',
                            label: 'AVG SPEED',
                          ),
                          _Figure(
                            value: _speed(entry.maxSpeedMps),
                            unit: 'km/h',
                            label: 'TOP SPEED',
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
    );
  }

  /// Speeds are shown without the unit on the card; the unit follows the
  /// number in smaller type elsewhere.
  static String _speed(double mps) => '${(mps * 3.6).round()}';
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.highlights});

  final RecapHighlights highlights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = highlights.weatherCode;
    final temperature = highlights.temperatureC;
    final achievement = highlights.achievementIds
        .map(AchievementKind.fromName)
        .nonNulls
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            highlights.sentence,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              InsightPill(
                icon: Icons.star_rounded,
                label:
                    '${highlights.score} · ${RideScore(highlights.score).label}',
                accent: AppColors.primary,
              ),
              if (code != null)
                InsightPill(
                  icon: InsightVisuals.weather(
                    WeatherCondition.fromWmo(code),
                    isDay: highlights.isDay,
                  ),
                  label: temperature == null
                      ? WeatherCondition.fromWmo(code).label
                      : '${temperature.round()}°',
                ),
              if (achievement != null) AchievementChip(kind: achievement),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, this.unit});

  final String value;
  final String label;

  /// A small unit set after the value, when it has one.
  final String? unit;

  static const double _valueSize = 16;
  static const double _labelSpacing = 1.1;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: AppTypography.stat(fontSize: _valueSize)),
                if (unit != null) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    unit!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: AppTypeScale.micro,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: _labelSpacing,
              fontSize: AppTypeScale.micro,
            ),
          ),
        ],
      ),
    );
  }
}
