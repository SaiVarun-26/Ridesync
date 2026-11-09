import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A dark surface card with a hairline border and an optional subtle neon glow.
///
/// Used as the base container for grouped content throughout the app. The glow
/// is intentionally restrained — bloom is a highlight, not a default.
class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.glowColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// When set, the card gains a soft outer glow in this color.
  final Color? glowColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: glow?.withValues(alpha: 0.35) ?? AppColors.divider,
        ),
        boxShadow: glow == null
            ? null
            : [
                BoxShadow(
                  color: glow.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
