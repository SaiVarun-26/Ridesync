import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../ride/domain/geo_point.dart';
import '../thumbnail/route_thumbnail_layout.dart';
import '../thumbnail/route_thumbnail_painter.dart';

/// The actual path a ride took, drawn small on a black tile with rounded
/// corners: a thin purple line, arrows, a start and a finish.
///
/// The route is laid out once per ride (see [RouteThumbnailLayout]) and the
/// result painted onto its own layer, so a list of them scrolls and presses
/// without redrawing anything. While a ride's preview is still being built
/// from its recorded route, the tile shows a quiet outline of one.
class RouteThumbnail extends StatelessWidget {
  const RouteThumbnail({
    super.key,
    required this.points,
    this.speedsMps = const [],
    this.size = defaultSize,
  });

  static const double defaultSize = 96;

  final List<GeoPoint> points;

  /// Speed at each of [points], when recorded.
  final List<double> speedsMps;

  final double size;

  @override
  Widget build(BuildContext context) {
    final layout = RouteThumbnailLayout.of(points, speedsMps);
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
              child: layout == null
                  ? const CustomPaint(
                      key: ValueKey('pending'),
                      painter: _PendingPainter(),
                    )
                  : CustomPaint(
                      key: ValueKey(layout),
                      painter: RouteThumbnailPainter(layout),
                    ),
            ),
          ),
        ),
      ),
    );
  }
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
