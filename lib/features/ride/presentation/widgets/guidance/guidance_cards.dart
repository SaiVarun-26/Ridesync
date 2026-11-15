import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_icon.dart';
import '../../../../../core/widgets/glass_panel.dart';
import '../../../../../core/widgets/pressable_scale.dart';
import '../../../../../core/widgets/pulse_indicator.dart';
import '../../../domain/guidance/route_maneuvers.dart';
import '../../../domain/guidance/route_progress.dart';
import '../../../domain/live/ride_format.dart';
import '../../guidance/guidance_controller.dart';
import 'route_complete_card.dart';

/// The icon for a manoeuvre.
IconData maneuverIcon(ManeuverKind kind) => switch (kind) {
  ManeuverKind.slightLeft => Icons.turn_slight_left_rounded,
  ManeuverKind.left => Icons.turn_left_rounded,
  ManeuverKind.sharpLeft => Icons.turn_sharp_left_rounded,
  ManeuverKind.slightRight => Icons.turn_slight_right_rounded,
  ManeuverKind.right => Icons.turn_right_rounded,
  ManeuverKind.sharpRight => Icons.turn_sharp_right_rounded,
  ManeuverKind.uTurn => Icons.u_turn_left_rounded,
  ManeuverKind.arrive => Icons.flag_rounded,
};

/// "250 m" with distances rounded the way a rider reads them on the move.
String guidanceDistance(double meters) {
  if (meters < 1000) {
    final step = meters < 100 ? 10 : 50;
    return '${(meters / step).round() * step} m';
  }
  return RideFormat.distance(meters);
}

/// The guidance card under the ride header. One card, many faces: the next
/// turn, the off-route warning and its two choices, the way back, and the
/// route-complete moment. Each change cross-fades in place, so the top of the
/// map never jumps.
class GuidanceCard extends StatelessWidget {
  const GuidanceCard({
    super.key,
    required this.state,
    required this.destinationName,
    required this.headingDegrees,
    required this.rideDuration,
    required this.rideDistanceMeters,
    required this.onReturn,
    required this.onContinue,
    required this.onAcknowledgeArrival,
  });

  final GuidanceState state;
  final String destinationName;

  /// The direction the map is facing (the rider's heading), for the arrow
  /// back to the route.
  final double? headingDegrees;

  final Duration rideDuration;
  final double rideDistanceMeters;

  final VoidCallback onReturn;
  final VoidCallback onContinue;
  final VoidCallback onAcknowledgeArrival;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    final Widget child;
    if (snapshot == null) {
      child = const SizedBox.shrink(key: ValueKey('none'));
    } else if (state.hasArrived) {
      child = state.arrivalAcknowledged
          ? const _Chip(
              key: ValueKey('arrived-chip'),
              icon: Icons.flag_rounded,
              label: 'Route complete',
              color: AppColors.primary,
              onTap: null,
            )
          : RouteCompleteCard(
              key: const ValueKey('arrived'),
              destinationName: destinationName,
              duration: rideDuration,
              distanceMeters: rideDistanceMeters,
              onDismiss: onAcknowledgeArrival,
            );
    } else if (state.isOffRoute && state.isReturning) {
      child = _ReturnCard(
        key: const ValueKey('returning'),
        snapshot: snapshot,
        headingDegrees: headingDegrees,
        onContinue: onContinue,
      );
    } else if (state.isOffRoute && state.offRouteDismissed) {
      child = _Chip(
        key: const ValueKey('off-chip'),
        icon: Icons.alt_route_rounded,
        label: 'Off route · ${guidanceDistance(snapshot.offsetMeters)}',
        color: AppColors.error,
        onTap: onReturn,
      );
    } else if (state.isOffRoute) {
      child = _OffRouteCard(
        key: const ValueKey('off'),
        snapshot: snapshot,
        onReturn: onReturn,
        onContinue: onContinue,
      );
    } else {
      child = _NextTurnCard(
        key: const ValueKey('turn'),
        snapshot: snapshot,
        destinationName: destinationName,
      );
    }
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}

class _NextTurnCard extends StatelessWidget {
  const _NextTurnCard({
    super.key,
    required this.snapshot,
    required this.destinationName,
  });

  final GuidanceSnapshot snapshot;
  final String destinationName;

  /// A second turn this close after the next one is announced with it.
  static const double _thenWithinMeters = 150;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = snapshot.next;
    final distance = snapshot.metersToNext ?? snapshot.remainingMeters;
    final kind = next?.kind ?? ManeuverKind.arrive;
    final after = snapshot.afterNext;
    final then =
        next != null &&
            after != null &&
            after.alongMeters - next.alongMeters <= _thenWithinMeters
        ? after.kind.thenPhrase
        : null;
    final instruction = kind == ManeuverKind.arrive
        ? destinationName
        : kind.instruction;
    return GlassPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _TurnBadge(kind: kind),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RollingText(
                  text: guidanceDistance(distance),
                  style: AppTypography.stat(fontSize: 26),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  kind == ManeuverKind.arrive
                      ? 'Arrive at $instruction'
                      : instruction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          if (then != null) ...[
            const SizedBox(width: AppSpacing.sm),
            _ThenChip(kind: after!.kind, label: then),
          ],
        ],
      ),
    );
  }
}

class _TurnBadge extends StatelessWidget {
  const _TurnBadge({required this.kind});

  final ManeuverKind kind;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: AppMotion.spring,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          maneuverIcon(kind),
          key: ValueKey(kind),
          size: AppIconSize.hero - 4,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ThenChip extends StatelessWidget {
  const _ThenChip({required this.kind, required this.label});

  final ManeuverKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.pill,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('then', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            maneuverIcon(kind),
            size: AppIconSize.small,
            color: AppColors.textPrimary,
            semanticLabel: label,
          ),
        ],
      ),
    );
  }
}

class _OffRouteCard extends StatelessWidget {
  const _OffRouteCard({
    super.key,
    required this.snapshot,
    required this.onReturn,
    required this.onContinue,
  });

  final GuidanceSnapshot snapshot;
  final VoidCallback onReturn;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      accent: AppColors.error,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const StatusDot(color: AppColors.error, live: true),
              const SizedBox(width: AppSpacing.sm),
              Text('Off route', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${guidanceDistance(snapshot.offsetMeters)} away',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  label: 'Return to route',
                  icon: Icons.u_turn_left_rounded,
                  primary: true,
                  onTap: onReturn,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _CardButton(
                  label: 'Continue',
                  icon: Icons.arrow_upward_rounded,
                  primary: false,
                  onTap: onContinue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({
    super.key,
    required this.snapshot,
    required this.headingDegrees,
    required this.onContinue,
  });

  final GuidanceSnapshot snapshot;
  final double? headingDegrees;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bearing = snapshot.rejoinBearing;
    // The arrow points the way back relative to where the rider faces (the
    // map is heading-up), or relative to north without a heading.
    final turn = bearing == null ? 0.0 : bearing - (headingDegrees ?? 0);
    final meters = snapshot.metersToRejoin ?? snapshot.offsetMeters;
    return GlassPanel(
      accent: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: turn * math.pi / 180),
              duration: AppMotion.slow,
              curve: AppMotion.curve,
              builder: (context, angle, child) =>
                  Transform.rotate(angle: angle, child: child),
              child: const Icon(
                Icons.navigation_rounded,
                color: AppColors.textPrimary,
                size: AppIconSize.hero - 6,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RollingText(
                  text: guidanceDistance(meters),
                  style: AppTypography.stat(fontSize: 26),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  bearing == null
                      ? 'Back to the route'
                      : 'Back to the route · ${RideFormat.compass(bearing)}',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          _CardButton(
            label: 'Continue',
            icon: null,
            primary: false,
            onTap: onContinue,
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : AppColors.textPrimary;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: primary ? AppColors.primary : AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: primary ? Colors.transparent : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppIconSize.small, color: foreground),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
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

/// A compact, one-line guidance state.
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = GlassPanel(
      accent: color,
      radius: AppRadius.pill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.small, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right_rounded,
              size: AppIconSize.small,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: onTap == null
          ? chip
          : PressableScale(
              child: GestureDetector(onTap: onTap, child: chip),
            ),
    );
  }
}

/// A figure that rolls softly to its new value instead of flicking.
class _RollingText extends StatelessWidget {
  const _RollingText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}
