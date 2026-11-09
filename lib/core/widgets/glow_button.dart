import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Visual emphasis levels for [GlowButton].
enum GlowButtonVariant {
  /// Filled, glowing — the single primary action on a screen.
  primary,

  /// Outlined, transparent fill — secondary actions.
  secondary,

  /// Subtle destructive styling (e.g. Leave Ride). Uses warning color
  /// restrained to text/border, never a loud red fill.
  destructive,
}

/// The app's primary call-to-action button. A pill with an optional neon glow,
/// a built-in loading state, and three emphasis [variant]s.
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GlowButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.accent = AppColors.route,
    this.expand = true,
  });

  final String label;

  /// Tapping callback. When `null` the button renders disabled.
  final VoidCallback? onPressed;

  final GlowButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  /// Accent color for the primary variant's fill and glow.
  final Color accent;

  /// When true the button stretches to the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;
    final (Color bg, Color fg, Color border, Color? glow) = switch (variant) {
      GlowButtonVariant.primary => (
          accent,
          Colors.white,
          accent,
          accent,
        ),
      GlowButtonVariant.secondary => (
          Colors.transparent,
          AppColors.textPrimary,
          AppColors.divider,
          null,
        ),
      GlowButtonVariant.destructive => (
          Colors.transparent,
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.4),
          null,
        ),
    };

    final Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          );

    final double opacity = enabled ? 1 : 0.45;

    return Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: (glow != null && enabled)
              ? [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.45),
                    blurRadius: 28,
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              width: expand ? double.infinity : null,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: border),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
