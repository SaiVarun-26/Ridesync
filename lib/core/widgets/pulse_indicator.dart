import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A small dot that breathes in and out, signalling that the app is waiting on
/// someone else (for example, the host). Calmer than a spinner.
class PulseIndicator extends StatefulWidget {
  const PulseIndicator({
    super.key,
    this.color = AppColors.primary,
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
  static const double _minOpacity = 0.35;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.breath,
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: _minOpacity,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.ambient));

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
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}

/// The small dot at the front of every status pill: it breathes while the
/// thing it describes is [live], and sits still otherwise.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.live = false});

  final Color color;
  final bool live;

  static const double size = 7;

  @override
  Widget build(BuildContext context) {
    if (live) return PulseIndicator(color: color, size: size);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
