import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_icon.dart';
import 'glass_panel.dart';
import 'pressable_scale.dart';

/// A round icon control with the app's physical press. With [glass] it floats
/// over a map or photo on frosted glass; without, it sits flat on the page.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.textPrimary,
    this.glass = false,
    this.child,
  });

  /// Diameter of the control; comfortably above the minimum touch target.
  static const double size = 44;

  final IconData icon;

  /// Read aloud by screen readers and shown on long press.
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final bool glass;

  /// Replaces the icon, for controls that draw their own (a compass needle).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final glyph =
        child ??
        Icon(
          icon,
          size: AppIconSize.large - 2,
          color: enabled ? color : AppColors.textTertiary,
        );
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: PressableScale(
          enabled: enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: glass
                  ? GlassPanel(
                      padding: EdgeInsets.zero,
                      radius: size,
                      child: Center(child: glyph),
                    )
                  : Center(child: glyph),
            ),
          ),
        ),
      ),
    );
  }
}
