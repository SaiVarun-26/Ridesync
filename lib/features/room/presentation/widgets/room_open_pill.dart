import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/pulse_indicator.dart';

/// Shows whether a room still takes riders, with the live rider count.
///
/// Open: a pulsing dot, "Open to join", or "Ride in progress" when the ride is
/// already under way (riders can still join it). Closed: a still red dot,
/// "Ride ended".
class RoomOpenPill extends StatelessWidget {
  const RoomOpenPill({
    super.key,
    required this.isOpen,
    required this.riders,
    this.isUnderway = false,
  });

  final bool isOpen;
  final int riders;

  /// Whether the ride has already left the lobby.
  final bool isUnderway;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.success : AppColors.error;
    final theme = Theme.of(context);
    final count = '$riders ${riders == 1 ? 'rider' : 'riders'}';
    final label = !isOpen
        ? 'Ride ended'
        : (isUnderway ? 'Ride in progress' : 'Open to join');
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      padding: AppSpacing.pill,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: color, live: isOpen),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '·',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AnimatedSwitcher(
            duration: AppMotion.normal,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              count,
              key: ValueKey(count),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
