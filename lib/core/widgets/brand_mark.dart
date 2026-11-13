import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The RideSync mark: an orbit with two riders on it.
///
/// A violet ring open at one corner, a bright rider at one end of the opening
/// and a deeper one at the other, and a still point in the middle: two riders,
/// one route, always in sync. Painted in code so it stays sharp at any size
/// and is the same mark used for the app icon.
///
/// With [breathing] on it swells very slightly and brightens, a calm signal
/// that the app is working.
class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.size = defaultSize, this.breathing = false});

  /// Diameter used when no [size] is given: the large, centred mark used on
  /// splash, onboarding, ride setup and the ride wrap-up.
  static const double defaultSize = hero;

  /// The mark on its own in the middle of a screen.
  static const double hero = 72;

  /// The mark beside a wordmark in a page header.
  static const double header = 26;

  final double size;
  final bool breathing;

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.breath,
  );

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
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = AppMotion.ambient.transform(_controller.value);
            return Transform.scale(
              scale: 1 + 0.035 * t,
              child: CustomPaint(painter: BrandMarkPainter(brightness: t)),
            );
          },
        ),
      ),
    );
  }
}

/// Paints the RideSync mark into whatever box it is given.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({this.brightness = 0});

  /// 0 to 1: how much brighter the ring is drawn.
  final double brightness;

  /// The opening in the ring is centred on this angle (top right).
  static const double _gapCenter = -math.pi / 4;
  static const double _gapWidth = math.pi / 3;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    final radius = side * 0.38;
    final stroke = side * 0.085;

    const start = _gapCenter + _gapWidth / 2;
    const sweep = 2 * math.pi - _gapWidth;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        AppColors.primary,
        AppColors.primaryHover,
        brightness,
      )!;

    canvas.drawArc(arcRect, start, sweep, false, ring);

    // The two riders at the ends of the opening.
    Offset onRing(double angle) =>
        center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final leading = onRing(_gapCenter - _gapWidth / 2);
    final trailing = onRing(_gapCenter + _gapWidth / 2);
    canvas
      ..drawCircle(leading, side * 0.07, Paint()..color = Colors.white)
      ..drawCircle(trailing, side * 0.055, Paint()..color = AppColors.primary)
      // The still point at the middle.
      ..drawCircle(center, side * 0.06, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) => old.brightness != brightness;
}
