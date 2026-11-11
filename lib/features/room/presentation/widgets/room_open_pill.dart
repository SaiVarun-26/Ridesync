import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/pulse_indicator.dart';

/// Shows whether a room still takes riders, with the live rider count.
///
/// Open: a pulsing green dot, "Open to join". Locked: a still red dot,
/// "Ride started".
class RoomOpenPill extends StatelessWidget {
  const RoomOpenPill({super.key, required this.isOpen, required this.riders});

  final bool isOpen;
  final int riders;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.neonGreen : AppColors.warning;
    final theme = Theme.of(context);
    final count = '$riders ${riders == 1 ? 'rider' : 'riders'}';
    return AnimatedContainer(
      duration: AppMotion.normal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm - 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOpen)
            PulseIndicator(color: color, size: 7)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isOpen ? 'Open to join' : 'Ride started',
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
