import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The RideSync mark: a glowing neon ring.
///
/// With [breathing] on, the glow slowly swells and fades, a calm signal that
/// the app is working (used while a ride initializes).
class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.size = defaultSize, this.breathing = false});

  /// Diameter used when no [size] is given.
  static const double defaultSize = 64;

  final double size;
  final bool breathing;

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  /// One full inhale-exhale is twice this duration.
  static const Duration _breathHalfPeriod = Duration(milliseconds: 2400);

  static const double _ringWidthFraction = 3 / 64;
  static const double _restGlowAlpha = 0.5;
  static const double _minGlowAlpha = 0.25;
  static const double _maxGlowAlpha = 0.65;
  static const double _restBlurFraction = 28 / 64;
  static const double _minBlurFraction = 18 / 64;
  static const double _maxBlurFraction = 40 / 64;
  static const double _glowSpread = -2;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _breathHalfPeriod);

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(BrandMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.breathing != widget.breathing) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.breathing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final glowAlpha = widget.breathing
            ? _minGlowAlpha + (_maxGlowAlpha - _minGlowAlpha) * t
            : _restGlowAlpha;
        final blurFraction = widget.breathing
            ? _minBlurFraction + (_maxBlurFraction - _minBlurFraction) * t
            : _restBlurFraction;
        return Container(
          height: widget.size,
          width: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.neonGreen,
              width: widget.size * _ringWidthFraction,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonGreen.withValues(alpha: glowAlpha),
                blurRadius: widget.size * blurFraction,
                spreadRadius: _glowSpread,
              ),
            ],
          ),
        );
      },
    );
  }
}
