import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A rider's identity: a glowing dot in their claimed color.
///
/// RideSync V1 has no rider icons, so this dot is how a rider is represented
/// everywhere (lobby, live ride, trails, summary, Ride Card). When [color] is
/// `null` (no color claimed yet) it renders as a hollow ring.
///
/// Color and glow changes animate, so claiming or switching a color reads as a
/// soft fade rather than a jump.
class RiderDot extends StatelessWidget {
  const RiderDot({
    super.key,
    required this.color,
    this.size = defaultSize,
    this.glow = true,
  });

  /// Diameter used when no [size] is given.
  static const double defaultSize = 12;

  /// The rider's color, or `null` if they have not claimed one.
  final Color? color;

  /// Diameter of the dot in logical pixels.
  final double size;

  /// Whether to draw the neon bloom around the dot.
  final bool glow;

  /// Bloom opacity relative to the dot color.
  static const double _glowAlpha = 0.65;

  /// Hollow-ring stroke width for an unclaimed rider.
  static const double _ringWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final dotColor = color;
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dotColor ?? Colors.transparent,
        border: dotColor == null
            ? Border.all(color: AppColors.textTertiary, width: _ringWidth)
            : null,
        boxShadow: glow && dotColor != null
            ? [
                BoxShadow(
                  color: dotColor.withValues(alpha: _glowAlpha),
                  blurRadius: size,
                  spreadRadius: size * 0.1,
                ),
              ]
            : null,
      ),
    );
  }
}
