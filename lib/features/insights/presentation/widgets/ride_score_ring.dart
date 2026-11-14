import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A ride score as a ring that fills to the score, with the number counting
/// up in the middle. Solid purple on a hairline track; no glow.
class RideScoreRing extends StatelessWidget {
  const RideScoreRing({
    super.key,
    required this.score,
    this.size = 84,
    this.progress = const AlwaysStoppedAnimation(1),
  });

  /// 0–100.
  final int score;
  final double size;

  /// 0 to 1: drives the fill and the count together.
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ride score $score out of 100',
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final t = progress.value.clamp(0.0, 1.0);
              return CustomPaint(
                painter: _RingPainter(fraction: score / 100 * t),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(score * t).round()}',
                        style: AppTypography.stat(fontSize: size * 0.34),
                      ),
                      Text(
                        'SCORE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: AppTypeScale.micro,
                          letterSpacing: 1.2,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.075;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2 + AppSpacing.xxs);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.border,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}
