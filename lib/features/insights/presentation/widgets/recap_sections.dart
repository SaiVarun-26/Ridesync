import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../domain/achievements/achievement.dart';
import '../../domain/analysis/ride_insights.dart';
import '../../domain/analysis/route_profile.dart';
import '../../domain/recap/ride_recap.dart';
import '../../domain/weather/weather_snapshot.dart';
import 'insight_visuals.dart';
import 'ride_score_ring.dart';

/// The ride's score and its recap sentence, side by side: the first thing a
/// rider reads about how the ride went.
class RecapCard extends StatelessWidget {
  const RecapCard({
    super.key,
    required this.recap,
    this.progress = const AlwaysStoppedAnimation(1),
  });

  final RideRecap recap;

  /// Fills the score ring and counts it up.
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      accent: AppColors.primary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RideScoreRing(score: recap.score.value, progress: progress),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recap.score.label, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  recap.sentence,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
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

/// Each achievement as a small card, springing in one after another.
class AchievementBadges extends StatelessWidget {
  const AchievementBadges({
    super.key,
    required this.achievements,
    this.delay = Duration.zero,
    this.holderName,
  });

  final List<Achievement> achievements;

  /// When the first badge starts to appear.
  final Duration delay;

  /// Names who earned an achievement, for ones earned by someone else.
  final String? Function(String uid)? holderName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, a) in achievements.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          FadeScaleIn(
            key: ValueKey(a.kind),
            delay: delay + AppMotion.stagger * i,
            duration: AppMotion.springDuration,
            blur: false,
            spring: true,
            child: _AchievementTile(
              achievement: a,
              holder: a.holderUid == null
                  ? null
                  : holderName?.call(a.holderUid!),
            ),
          ),
        ],
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, this.holder});

  final Achievement achievement;
  final String? holder;

  static const double _disc = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: _disc,
            height: _disc,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
            child: Icon(
              InsightVisuals.achievement(achievement.kind),
              size: AppIconSize.medium,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  holder == null
                      ? achievement.detail
                      : '$holder · ${achievement.detail}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
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

/// A compact achievement chip, for tight spaces like history cards.
class AchievementChip extends StatelessWidget {
  const AchievementChip({super.key, required this.kind});

  final AchievementKind kind;

  @override
  Widget build(BuildContext context) {
    return InsightPill(
      icon: InsightVisuals.achievement(kind),
      label: InsightVisuals.achievementTitle(kind),
      accent: AppColors.primary,
    );
  }
}

/// A small rounded pill with an icon and a label.
class InsightPill extends StatelessWidget {
  const InsightPill({
    super.key,
    required this.icon,
    required this.label,
    this.accent = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.pill,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.small, color: accent),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: accent, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The weather the ride started in. Only built when there is weather to
/// show; there is no empty state.
class WeatherSnapshotCard extends StatelessWidget {
  const WeatherSnapshotCard({super.key, required this.weather});

  final WeatherSnapshot weather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final humidity = weather.humidityPercent;
    final wind = weather.windKmh;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                InsightVisuals.weather(weather.condition, isDay: weather.isDay),
                size: AppIconSize.hero,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.lg),
              Text(
                weather.temperatureLabel,
                style: AppTypography.stat(fontSize: 34),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  weather.condition.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (humidity != null || wind != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (humidity != null)
                  Expanded(
                    child: _Figure(
                      label: 'HUMIDITY',
                      value: '${humidity.round()}%',
                    ),
                  ),
                if (wind != null)
                  Expanded(
                    child: _Figure(
                      label: 'WIND',
                      value: '${wind.round()} km/h',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'At the start of the ride · Weather by Open-Meteo.com',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The ride's insights as a two-column grid of compact tiles.
class InsightGrid extends StatelessWidget {
  const InsightGrid({super.key, required this.insights});

  final List<RideInsight> insights;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final insight in insights)
              SizedBox(
                width: width,
                child: _InsightTile(insight: insight),
              ),
          ],
        );
      },
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final RideInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = insight.score;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                InsightVisuals.insight(insight.kind),
                size: AppIconSize.small,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  insight.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: AppTypeScale.micro,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(insight.value, style: AppTypography.stat(fontSize: 22)),
          ),
          if (score != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _Meter(value: score / 100),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            insight.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the route was like: an estimate of its character, its shape, and a
/// few measured figures.
class RouteIntelligenceCard extends StatelessWidget {
  const RouteIntelligenceCard({super.key, required this.route});

  final RouteProfile route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(route.character.label, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Estimated from the route · ${route.shape.description}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Figure(label: 'SHAPE', value: route.shape.label),
              ),
              Expanded(
                child: _Figure(label: 'TURNS', value: '${route.turnCount}'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'TWISTINESS',
                  value: route.twistiness.label,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'LONGEST STRAIGHT',
                  value: RideFormat.distance(route.longestStraightMeters),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'INTENSITY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: AppTypeScale.micro,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                route.intensity.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Meter(value: route.intensityScore / 100),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            fontSize: AppTypeScale.micro,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: AppTypography.stat(fontSize: AppTypeScale.statSmall),
        ),
      ],
    );
  }
}

/// A thin solid bar, filled to [value] (0 to 1).
class _Meter extends StatelessWidget {
  const _Meter({required this.value});

  final double value;

  static const double _height = 4;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.border),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: const ColoredBox(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
