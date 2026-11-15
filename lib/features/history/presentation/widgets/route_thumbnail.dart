import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../ride/domain/geo_point.dart';
import '../thumbnail/route_thumbnail_layout.dart';
import '../thumbnail/route_thumbnail_painter.dart';

/// The actual path a ride took, drawn small on a black tile with rounded
/// corners: a thin line in the rider's own colour, arrows, a start and a
/// finish.
///
/// The route is laid out once per ride (see [RouteThumbnailLayout]) and the
/// result painted onto its own layer, so a list of them scrolls and presses
/// without redrawing anything. While a ride's preview is still being built
/// from its recorded route, the tile shows a quiet outline of one; a ride that
/// never moved shows a single marker where it stayed instead.
class RouteThumbnail extends StatelessWidget {
  const RouteThumbnail({
    super.key,
    required this.points,
    this.speedsMps = const [],
    this.size = defaultSize,
    this.stationary = false,
    this.color,
  });

  static const double defaultSize = 96;

  /// The colour the rider had in this ride. While it is not known yet (a ride
  /// saved before colours were recorded, being looked up) the route is drawn
  /// in a neutral white; it is never the brand purple.
  final Color? color;

  final List<GeoPoint> points;

  /// Speed at each of [points], when recorded.
  final List<double> speedsMps;

  final double size;

  /// The ride covered no real distance, so there is no route to wait for:
  /// with no points, a marker is drawn rather than the "on its way" outline.
  final bool stationary;

  @override
  Widget build(BuildContext context) {
    final layout = RouteThumbnailLayout.of(points, speedsMps);
    final tone = color ?? AppColors.textPrimary;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: AnimatedSwitcher(
              duration: AppMotion.normal,
              switchInCurve: AppMotion.curve,
              // Each painter fills the whole tile. The switcher lays its
              // children out loosely, and a childless CustomPaint given loose
              // constraints shrinks to nothing, which drew the whole route
              // into a single point.
              child: layout != null
                  ? SizedBox.expand(
                      // The colour is part of the key, so a ride whose colour
                      // arrives late fades into it instead of snapping.
                      key: ValueKey((layout, tone)),
                      child: CustomPaint(
                        painter: RouteThumbnailPainter(layout, color: tone),
                      ),
                    )
                  : stationary
                  ? SizedBox.expand(
                      key: ValueKey(('stationary', tone)),
                      child: CustomPaint(painter: _StationaryPainter(tone)),
                    )
                  : const SizedBox.expand(
                      key: ValueKey('pending'),
                      child: CustomPaint(painter: _PendingPainter()),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A ride that never moved: the start marker in the middle of the tile with a
/// faint ring around it, the same marker a route starts from.
class _StationaryPainter extends CustomPainter {
  const _StationaryPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final s = size.shortestSide;
    canvas
      ..drawCircle(
        center,
        s * 0.16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: 0.35),
      )
      ..drawCircle(center, s * 0.055, Paint()..color = Colors.white)
      ..drawCircle(center, s * 0.028, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StationaryPainter old) => old.color != color;
}

/// A faint dashed outline of a route, with a dot at each end, shown while a
/// ride's real route is on its way.
class _PendingPainter extends CustomPainter {
  const _PendingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final path = Path()
      ..moveTo(s * 0.2, s * 0.72)
      ..cubicTo(s * 0.2, s * 0.2, s * 0.8, s * 0.8, s * 0.8, s * 0.28);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = AppColors.textTertiary.withValues(alpha: 0.6);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 4.5), paint);
      }
    }
    final dot = Paint()..color = AppColors.textTertiary;
    canvas
      ..drawCircle(Offset(s * 0.2, s * 0.72), 2.6, dot)
      ..drawCircle(Offset(s * 0.8, s * 0.28), 2.6, dot);
  }

  @override
  bool shouldRepaint(_PendingPainter old) => false;
}
