import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_icon.dart';
import '../../../../../core/widgets/glass_panel.dart';
import '../../../../../core/widgets/pressable_scale.dart';
import '../../../domain/live/ride_format.dart';

/// The moment the rider reaches the destination: a ring sweeps closed around
/// a check that draws itself in, a single ripple settles outward, and the
/// card states where they arrived and what the ride took. Tap to tuck it
/// away into a small chip.
class RouteCompleteCard extends StatefulWidget {
  const RouteCompleteCard({
    super.key,
    required this.destinationName,
    required this.duration,
    required this.distanceMeters,
    required this.onDismiss,
  });

  final String destinationName;
  final Duration duration;
  final double distanceMeters;
  final VoidCallback onDismiss;

  @override
  State<RouteCompleteCard> createState() => _RouteCompleteCardState();
}

class _RouteCompleteCardState extends State<RouteCompleteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label:
          'Route complete. Arrived at ${widget.destinationName}. Tap to close.',
      excludeSemantics: true,
      child: PressableScale(
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: GlassPanel(
            accent: AppColors.primary,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 56,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CompletePainter(progress: _controller),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Route complete', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        widget.destinationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${RideFormat.distance(widget.distanceMeters)} · '
                        '${RideFormat.duration(widget.duration)}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.close_rounded,
                  size: AppIconSize.small,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletePainter extends CustomPainter {
  _CompletePainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;

    // 0–0.45: the ring sweeps closed.
    final ring = AppMotion.curve.transform((t / 0.45).clamp(0.0, 1.0));
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()..color = AppColors.primary.withValues(alpha: 0.16 * ring),
      )
      ..drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );

    // 0.35–0.75: the check draws in.
    final check = AppMotion.curve.transform(((t - 0.35) / 0.4).clamp(0.0, 1.0));
    if (check > 0) {
      final s = radius * 0.5;
      final path = Path()
        ..moveTo(center.dx - s, center.dy + s * 0.05)
        ..lineTo(center.dx - s * 0.25, center.dy + s * 0.7)
        ..lineTo(center.dx + s, center.dy - s * 0.6);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * check),
        Paint()
          ..color = AppColors.textPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 0.5–1: one ripple settles outward and fades.
    final ripple = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    if (ripple > 0 && ripple < 1) {
      canvas.drawCircle(
        center,
        radius + 4 * AppMotion.curve.transform(ripple),
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.5 * (1 - ripple))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_CompletePainter old) => false;
}
