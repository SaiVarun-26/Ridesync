import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_icon.dart';
import '../../../../../core/widgets/glass_panel.dart';
import '../../../../../core/widgets/pressable_scale.dart';
import '../../../../../core/widgets/pulse_indicator.dart';
import '../../../domain/geo_point.dart';
import '../../../domain/safety/ride_signal.dart';
import '../guidance/guidance_cards.dart' show guidanceDistance;

/// The small shield in the ride header that opens the safety tools. A red
/// dot shows while this rider's own attention call is up.
class SafetyButton extends StatelessWidget {
  const SafetyButton({
    super.key,
    required this.onPressed,
    required this.alertActive,
  });

  final VoidCallback onPressed;
  final bool alertActive;

  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: alertActive ? 'Safety. Your alert is on.' : 'Safety',
      excludeSemantics: true,
      child: PressableScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: _size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceRaised,
                      border: Border.all(
                        color: alertActive ? AppColors.error : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      size: AppIconSize.small + 2,
                      color: alertActive
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (alertActive)
                  const Positioned(
                    right: -1,
                    top: -1,
                    child: StatusDot(color: AppColors.error, live: true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon, accent and wording of a signal.
({IconData icon, Color color, String text}) signalLook(
  RideSignalKind kind,
  String name,
) => switch (kind) {
  RideSignalKind.attention => (
    icon: Icons.priority_high_rounded,
    color: AppColors.error,
    text: '$name needs attention',
  ),
  RideSignalKind.regroup => (
    icon: Icons.groups_rounded,
    color: AppColors.primary,
    text: '$name asks to regroup',
  ),
  RideSignalKind.followMe => (
    icon: Icons.near_me_rounded,
    color: AppColors.primary,
    text: '$name: follow me',
  ),
  RideSignalKind.ok => (
    icon: Icons.check_rounded,
    color: AppColors.primary,
    text: '$name checked in · OK',
  ),
};

/// Another rider's signal, over the top of the map. Tap to see where they
/// are.
class RideSignalBanner extends StatelessWidget {
  const RideSignalBanner({
    super.key,
    required this.signal,
    required this.name,
    required this.myPoint,
    required this.moreCount,
    required this.onShow,
  });

  final RideSignal signal;
  final String name;
  final GeoPoint? myPoint;

  /// How many other signals are waiting behind this one.
  final int moreCount;

  /// Shows the rider on the map; `null` when their position is unknown.
  final VoidCallback? onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final look = signalLook(signal.kind, name);
    final where = signal.point;
    final distance = where == null || myPoint == null
        ? null
        : guidanceDistance(myPoint!.distanceMetersTo(where));
    final panel = GlassPanel(
      accent: look.color,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: look.color.withValues(alpha: 0.18),
            ),
            child: Icon(look.icon, size: AppIconSize.small + 2, color: look.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  look.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (distance != null || moreCount > 0) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      if (distance != null) '$distance away',
                      if (moreCount > 0) '+$moreCount more',
                    ].join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onShow != null)
            const Icon(
              Icons.my_location_rounded,
              size: AppIconSize.medium,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
    return Semantics(
      liveRegion: true,
      button: onShow != null,
      label: [look.text, if (distance != null) '$distance away'].join(', '),
      excludeSemantics: true,
      child: onShow == null
          ? panel
          : PressableScale(
              child: GestureDetector(onTap: onShow, child: panel),
            ),
    );
  }
}

/// A round control floating over the map's edge.
class MapFloatingButton extends StatelessWidget {
  const MapFloatingButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: PressableScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 44,
              child: GlassPanel(
                padding: EdgeInsets.zero,
                radius: 44,
                child: Center(
                  child: Icon(icon, size: AppIconSize.medium, color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
