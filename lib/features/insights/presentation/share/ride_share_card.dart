import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/rider_palette.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/brand_wordmark.dart';
import '../../../history/presentation/widgets/route_thumbnail.dart';
import '../../domain/share/share_card.dart';
import '../widgets/insight_visuals.dart';

/// The shareable ride card, in story format (9:16).
///
/// Always laid out at exactly [size] logical pixels, whatever the screen, so
/// the exported image looks the same on every phone; it is shown scaled down
/// as a preview and captured at [exportPixelRatio] (1080 × 1920). Pure black
/// with the RideSync purple, the route drawn large, the ride's figures and
/// the brand: built to be posted, not screenshotted.
class RideShareCard extends StatelessWidget {
  const RideShareCard({super.key, required this.data});

  final ShareCardData data;

  static const Size size = Size(360, 640);

  /// Renders the card at 1080 × 1920.
  static const double exportPixelRatio = 3;

  /// The route's size when there is room for it.
  static const double _routeSize = 280;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Fixed text size, so the system font scale cannot reflow the image.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandWordmark(height: 20),
                    const SizedBox(width: AppSpacing.md),
                    // Gives way before the brand does.
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _ScoreBadge(
                            score: data.score,
                            label: data.scoreLabel,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.weatherLabel == null
                      ? data.dateLabel
                      : '${data.dateLabel}  ·  ${data.weatherLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                // The route takes whatever room the text leaves, up to its
                // full size, so nothing can push the card out of shape.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final side = [
                          constraints.maxWidth,
                          constraints.maxHeight,
                          _routeSize,
                        ].reduce((a, b) => a < b ? a : b);
                        if (data.routePoints.length < 2 || side < 48) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: RouteThumbnail(
                            points: data.routePoints,
                            speedsMps: data.routeSpeedsMps,
                            color: RiderPalette.colorById(
                              data.routeColorId,
                            )?.color,
                            size: side,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(label: 'DISTANCE', value: data.distance),
                    ),
                    Expanded(
                      child: _Stat(label: 'TIME', value: data.duration),
                    ),
                    Expanded(
                      child: _Stat(label: 'RIDERS', value: data.riders),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'AVG SPEED',
                        value: data.averageSpeed,
                      ),
                    ),
                    Expanded(
                      child: _Stat(label: 'TOP SPEED', value: data.topSpeed),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                if (data.badge != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _BadgeStrip(
                    icon: InsightVisuals.achievement(data.badge!.kind),
                    title: data.badge!.title,
                    detail: data.badge!.detail,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Ridden together on RideSync',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.label});

  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.pill,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$score · $label',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
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
          child: Text(value, style: AppTypography.stat(fontSize: 20)),
        ),
      ],
    );
  }
}

class _BadgeStrip extends StatelessWidget {
  const _BadgeStrip({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.large, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
