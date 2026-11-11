import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../ride/domain/geo_point.dart';

/// A miniature of a ride's route: its shape drawn as a glowing line on a dark
/// tile, with a dot at the start. Paints no map, so it costs almost nothing in
/// a list.
class RouteThumbnail extends StatelessWidget {
  const RouteThumbnail({
    super.key,
    required this.points,
    this.size = defaultSize,
    this.color = AppColors.neonGreen,
  });

  static const double defaultSize = 84;

  final List<GeoPoint> points;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: points.length < 2
              ? Icon(
                  Icons.route_outlined,
                  color: AppColors.textTertiary,
                  size: size * 0.34,
                )
              : CustomPaint(painter: _RoutePainter(points, color)),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points, this.color);

  final List<GeoPoint> points;
  final Color color;

  static const double _inset = 12;

  @override
  void paint(Canvas canvas, Size size) {
    // Flatten latitude/longitude so a degree of longitude is no wider than a
    // degree of latitude at this place on Earth.
    final meanLat =
        points.fold<double>(0, (sum, p) => sum + p.latitude) / points.length;
    final xScale = math.cos(meanLat * math.pi / 180);
    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final p in points) {
      final x = p.longitude * xScale;
      final y = -p.latitude;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final width = math.max(maxX - minX, 1e-9);
    final height = math.max(maxY - minY, 1e-9);
    final available = size.width - 2 * _inset;
    final scale = math.min(
      available / width,
      (size.height - 2 * _inset) / height,
    );
    final dx = (size.width - width * scale) / 2;
    final dy = (size.height - height * scale) / 2;

    Offset at(GeoPoint p) => Offset(
      dx + (p.longitude * xScale - minX) * scale,
      dy + (-p.latitude - minY) * scale,
    );

    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }

    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      )
      ..drawCircle(
        at(points.first),
        3.2,
        Paint()..color = AppColors.textPrimary,
      )
      ..drawCircle(at(points.last), 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      !identical(old.points, points) || old.color != color;
}
