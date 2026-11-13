import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// A panel that floats over the map and other content.
///
/// A translucent card-coloured surface that softly blurs what is behind it,
/// edged with a hairline border. An [accent] swaps the border for a line in
/// that colour, the way a panel is marked as belonging to someone. It has
/// no gradient and no glow: only a very large, very faint shadow to lift it.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Colour of the border; the neutral hairline when `null`.
  final Color? accent;
  final double radius;

  // Kept moderate on purpose: panels sit over a live map that repaints every
  // frame, and a blur has to be redone each time what is behind it changes.
  static const double _blurSigma = 12;
  static const double _fillAlpha = 0.82;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: AppShadows.rest,
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
                color: accent?.withValues(alpha: 0.6) ?? AppColors.border,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
