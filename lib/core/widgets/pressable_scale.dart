import 'package:flutter/widgets.dart';

/// Gives its child a small, quick "press in" while a finger is down on it.
///
/// Listens to raw pointer events, so it never competes with the child's own
/// taps or with scrolling. Only the scale animation rebuilds; the child itself
/// is built once.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = defaultPressedScale,
    this.onPressedChanged,
  });

  static const double defaultPressedScale = 0.97;

  /// Told when a finger goes down on, or lifts off, the child.
  final ValueChanged<bool>? onPressedChanged;

  final Widget child;

  /// When false the child does not react to presses.
  final bool enabled;

  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
    widget.onPressedChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && widget.enabled ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
