import 'package:flutter/material.dart';

import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/pressable_scale.dart';

/// Pause and End Ride, as two compact labelled pills at the foot of the
/// map's controls, always in view, so how to pause or finish a ride is clear
/// at a glance. Single taps only.
///
/// Pause is purple (❚❚ Pause) and turns into Resume (▶, green) while the
/// ride is paused. End Ride is red with a white stop icon.
class RideActionButtons extends StatelessWidget {
  const RideActionButtons({
    super.key,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
  });

  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  /// The pills' height: the same as the round map buttons.
  static const double height = 44;

  /// Resume's green.
  static const Color resumeColor = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.normal,
          switchInCurve: AppMotion.curve,
          switchOutCurve: AppMotion.exit,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: isPaused
              ? _Pill(
                  key: const ValueKey('resume'),
                  label: 'Resume',
                  icon: Icons.play_arrow_rounded,
                  color: resumeColor,
                  semantics: 'Resume ride',
                  onTap: onResume,
                )
              : _Pill(
                  key: const ValueKey('pause'),
                  label: 'Pause',
                  icon: Icons.pause_rounded,
                  color: AppColors.primary,
                  semantics: 'Pause ride',
                  onTap: onPause,
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Pill(
          label: 'End Ride',
          icon: Icons.stop_rounded,
          color: AppColors.error,
          semantics: 'End ride',
          onTap: onEnd,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.semantics,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: PressableScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            AppHaptics.selection();
            onTap();
          },
          child: Container(
            height: RideActionButtons.height,
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.rest,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppIconSize.medium, color: Colors.white),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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
