import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../ride/domain/live/ride_format.dart';

/// How fast a rider went over the course of a ride: a violet line with a soft
/// fill beneath it, drawn from left to right as [progress] goes from 0 to 1,
/// with the average marked.
class SpeedChart extends StatelessWidget {
  const SpeedChart({
    super.key,
    required this.speedsMps,
    required this.progress,
    this.height = 140,
  });

  /// Speed at evenly spaced moments of the ride, in meters per second.
  final List<double> speedsMps;

  /// How much of the line is drawn, 0 to 1.
  final Animation<double> progress;

  final double height;

  /// More points than this say nothing extra at phone width.
  static const int _maxPoints = 90;

  @override
  Widget build(BuildContext context) {
    final samples = _downsample(speedsMps);
    final peak = samples.fold<double>(0, math.max);
    final average = samples.isEmpty
        ? 0.0
        : samples.reduce((a, b) => a + b) / samples.length;
    final label = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: AppColors.textTertiary);

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ChartPainter(
                  samples: samples,
                  average: average,
                  progress: progress,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Text(RideFormat.speed(peak), style: label),
          ),
          Positioned(
            right: 0,
            top: AppSpacing.xs,
            child: Text('avg ${RideFormat.speed(average)}', style: label),
          ),
        ],
      ),
    );
  }

  static List<double> _downsample(List<double> speeds) {
    if (speeds.length <= _maxPoints) return speeds;
    final step = (speeds.length - 1) / (_maxPoints - 1);
    return [for (var i = 0; i < _maxPoints; i++) speeds[(i * step).round()]];
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.samples,
    required this.average,
    required this.progress,
  }) : super(repaint: progress);

  final List<double> samples;
  final double average;
  final Animation<double> progress;

  static const double _topPad = 18;
  static const double _bottomPad = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      0,
      _topPad,
      size.width,
      size.height - _bottomPad,
    );

    // Faint guide lines.
    final guide = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = plot.top + plot.height * i / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), guide);
    }
    if (samples.length < 2) return;

    final peak = math.max(samples.fold<double>(0, math.max), 1.0);
    Offset at(int i) => Offset(
      plot.left + plot.width * i / (samples.length - 1),
      plot.bottom - plot.height * (samples[i] / peak),
    );

    final shown = (samples.length - 1) * progress.value.clamp(0.0, 1.0);
    final whole = shown.floor();
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i <= whole; i++) {
      final o = at(i);
      line.lineTo(o.dx, o.dy);
    }
    var tip = at(whole);
    if (whole < samples.length - 1) {
      tip = Offset.lerp(at(whole), at(whole + 1), shown - whole)!;
      line.lineTo(tip.dx, tip.dy);
    }

    final fill = Path.from(line)
      ..lineTo(tip.dx, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()..color = AppColors.primary.withValues(alpha: 0.14),
      )
      ..drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.primary,
      );

    // The average, as a dashed line once the chart has drawn.
    final done = progress.value >= 1;
    if (done) {
      final y = plot.bottom - plot.height * (average / peak);
      final dash = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (var x = plot.left; x < plot.right; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, plot.right), y),
          dash,
        );
      }
    }
    canvas.drawCircle(tip, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      !identical(old.samples, samples) || old.average != average;
}
