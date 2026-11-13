import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Gives its child a physical press: it sinks and dims a little while a
/// finger is down, then springs back with a touch of overshoot when it lifts.
/// A light haptic marks the touch.
///
/// This is RideSync's replacement for the Material ripple. It listens to raw
/// pointer events, so it never competes with the child's own taps or with
/// scrolling, and only the transform and opacity rebuild; the child itself is
/// built once.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = defaultPressedScale,
    this.pressedOpacity = defaultPressedOpacity,
    this.haptic = true,
    this.onPressedChanged,
  });

  static const double defaultPressedScale = 0.965;
  static const double defaultPressedOpacity = 0.86;

  final Widget child;

  /// When false the child does not react to presses.
  final bool enabled;

  final double pressedScale;
  final double pressedOpacity;

  /// Whether touching down gives a light haptic tick.
  final bool haptic;

  /// Told when a finger goes down on, or lifts off, the child.
  final ValueChanged<bool>? onPressedChanged;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  /// 0 at rest, 1 fully pressed. Unbounded so the spring may overshoot past
  /// rest on release.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  static const double _hoverScale = 1.015;

  bool _down = false;
  bool _hovered = false;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _set(bool down) {
    if (_down == down || !mounted) return;
    _down = down;
    _press.animateWith(
      SpringSimulation(
        down ? AppMotion.pressIn : AppMotion.pressOut,
        _press.value,
        down ? 1 : 0,
        _press.velocity,
      ),
    );
    widget.onPressedChanged?.call(down);
  }

  @override
  void didUpdateWidget(PressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _down) _set(false);
  }

  void _setHover(bool value) {
    if (_hovered != value && mounted) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    // On desktop and web a pointer resting over the control lifts it a touch.
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedScale(
        scale: _hovered && widget.enabled ? _hoverScale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: _pressable(),
      ),
    );
  }

  Widget _pressable() {
    return Listener(
      onPointerDown: widget.enabled
          ? (_) {
              if (widget.haptic) HapticFeedback.selectionClick();
              _set(true);
            }
          : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedBuilder(
        animation: _press,
        child: widget.child,
        builder: (context, child) {
          final t = _press.value;
          return Opacity(
            opacity: (1 - (1 - widget.pressedOpacity) * t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1 - (1 - widget.pressedScale) * t,
              child: child,
            ),
          );
        },
      ),
    );
  }
}
