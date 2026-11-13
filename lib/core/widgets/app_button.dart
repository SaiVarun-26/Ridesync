import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';
import 'ride_loader.dart';

/// Visual emphasis levels for [AppButton].
enum AppButtonVariant {
  /// Solid RideSync purple: the one main action on a screen.
  primary,

  /// A solid card-coloured button with a hairline border: supporting actions.
  secondary,

  /// Outlined in the error colour: leaving or ending something.
  destructive,
}

/// The app's only button. A pill in one solid colour with a built-in loading
/// state and three emphasis [variant]s.
///
/// It is alive without being loud: it brightens a touch when hovered, darkens
/// and presses in under a finger, fades up when it becomes available, and
/// turns into the RideSync loader (with the button easing to fit) when it is
/// working. There are no gradients and no shadows.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isSuccess = false,
    this.expand = true,
    this.verticalPadding = AppSpacing.lg,
  });

  final String label;

  /// Tapping callback. When `null` the button renders disabled.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  /// The action just succeeded: the loader turns into a check. Takes
  /// precedence over [isLoading], and the button ignores taps meanwhile.
  final bool isSuccess;

  /// When true the button stretches to the available width.
  final bool expand;

  /// Space above and below the label; raise it for a taller button.
  final double verticalPadding;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled =>
      widget.onPressed != null && !widget.isLoading && !widget.isSuccess;

  (Color fill, Color border, Color foreground) _colors() {
    final active = _enabled;
    return switch (widget.variant) {
      AppButtonVariant.primary => (
        active && _pressed
            ? AppColors.primaryPressed
            : (active && _hovered ? AppColors.primaryHover : AppColors.primary),
        Colors.transparent,
        Colors.white,
      ),
      AppButtonVariant.secondary => (
        active && _pressed
            ? AppColors.background
            : (active && _hovered
                  ? AppColors.surfaceRaised
                  : AppColors.surface),
        AppColors.border,
        AppColors.textPrimary,
      ),
      AppButtonVariant.destructive => (
        active && (_pressed || _hovered)
            ? AppColors.error.withValues(alpha: 0.10)
            : Colors.transparent,
        AppColors.error.withValues(alpha: 0.5),
        AppColors.error,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    final (fill, border, foreground) = _colors();
    final dimmed =
        widget.onPressed == null && !widget.isLoading && !widget.isSuccess;

    final label = Row(
      key: const ValueKey('label'),
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: AppIconSize.medium, color: foreground),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: AppTypeScale.button,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );

    return PressableScale(
      enabled: _enabled,
      onPressedChanged: (down) => setState(() => _pressed = down),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedOpacity(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          opacity: dimmed ? 0.4 : 1,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: Border.all(color: border),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _enabled ? widget.onPressed : null,
                borderRadius: radius,
                splashFactory: NoSplash.splashFactory,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                child: Container(
                  width: widget.expand ? double.infinity : null,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: widget.verticalPadding,
                  ),
                  // The label and the loader trade places; the button eases
                  // to fit rather than jumping.
                  child: AnimatedSize(
                    duration: AppMotion.normal,
                    curve: AppMotion.curve,
                    child: SizedBox(
                      height: 22,
                      child: AnimatedSwitcher(
                        duration: AppMotion.normal,
                        switchInCurve: AppMotion.curve,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.85,
                              end: 1,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: widget.isSuccess
                            ? Icon(
                                Icons.check_rounded,
                                key: const ValueKey('success'),
                                size: AppIconSize.large,
                                color: foreground,
                              )
                            : widget.isLoading
                            ? Center(
                                key: const ValueKey('loader'),
                                child: RideLoader(
                                  size: RideLoader.inline,
                                  color: foreground,
                                ),
                              )
                            : label,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
