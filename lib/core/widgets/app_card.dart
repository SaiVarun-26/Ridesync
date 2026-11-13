import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import 'pressable_scale.dart';

/// A solid card with a hairline border: the base container for grouped
/// content.
///
/// An [accent] swaps the hairline for a line in that colour. When it has an
/// [onTap] it behaves like a history card: it presses in under the finger,
/// its border warms to purple and its shadow deepens, then it springs back.
/// A very large, very faint shadow separates it from the page; nothing glows.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Colour of the border; the neutral hairline when `null`.
  final Color? accent;

  final VoidCallback? onTap;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _lifted = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    final card = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: _lifted
              ? AppColors.primary.withValues(alpha: 0.7)
              : widget.accent?.withValues(alpha: 0.6) ?? AppColors.border,
        ),
        boxShadow: _lifted ? AppShadows.lifted : AppShadows.rest,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
    if (widget.onTap == null) return card;
    return PressableScale(
      onPressedChanged: (down) => setState(() => _lifted = down),
      child: card,
    );
  }
}
