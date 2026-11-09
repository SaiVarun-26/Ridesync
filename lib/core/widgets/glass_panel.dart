import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A frosted, translucent card that floats over the map.
///
/// Blurs whatever is behind it, adds a hairline border, and optionally a soft
/// neon [glowColor].
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.glowColor,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glowColor;
  final double radius;

  static const double _blurSigma = 20;
  static const double _fillAlpha = 0.72;
  static const double _borderAlpha = 0.08;
  static const double _glowAlpha = 0.22;
  static const double _glowBlur = 30;
  static const double _glowSpread = -8;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final glow = glowColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: glow == null
            ? null
            : [
                BoxShadow(
                  color: glow.withValues(alpha: _glowAlpha),
                  blurRadius: _glowBlur,
                  spreadRadius: _glowSpread,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: _fillAlpha),
              borderRadius: borderRadius,
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: _borderAlpha),
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
