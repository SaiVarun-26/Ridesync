import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A small dot that breathes in and out, signalling that the app is waiting on
/// someone else (for example, the host). Calmer than a spinner.
class PulseIndicator extends StatefulWidget {
  const PulseIndicator({
    super.key,
    this.color = AppColors.route,
    this.size = defaultSize,
  });

  /// Diameter used when no [size] is given.
  static const double defaultSize = 10;

  final Color color;
  final double size;

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(milliseconds: 1200);
  static const double _minOpacity = 0.35;
  static const double _glowAlpha = 0.6;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _period)
        ..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: _minOpacity,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _glowAlpha),
              blurRadius: widget.size,
            ),
          ],
        ),
      ),
    );
  }
}
