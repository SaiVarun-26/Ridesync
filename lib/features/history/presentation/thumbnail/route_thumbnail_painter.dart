import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'route_thumbnail_layout.dart';

/// Draws a [RouteThumbnailLayout]: the route itself and nothing else. No map,
/// no tiles, no labels.
///
/// A thin, clean line with rounded caps and joins, in the brand purple. Speed
/// shows only as a slight change of tone along it (a little deeper where the
/// rider was slow, a little lighter where they were fast), so the colour stays
/// the brand's. A few small arrows show which way the ride went, with a start
/// dot and a tiny chequered flag at the finish.
class RouteThumbnailPainter extends CustomPainter {
  RouteThumbnailPainter(this.layout);

  final RouteThumbnailLayout layout;

  /// Room kept clear around the route, as a share of the tile, for the line
  /// and the markers.
  static const double _inset = 0.17;

  static const int _toneSteps = 10;

  /// Slowest and fastest tones: the brand purple, a touch deeper and a touch
  /// lighter. Close enough to read as one colour.
  static final Color _slow = Color.lerp(AppColors.primary, Colors.black, 0.28)!;
  static final Color _fast = Color.lerp(AppColors.primary, Colors.white, 0.42)!;
  static final List<Color> _tones = [
    for (var i = 0; i < _toneSteps; i++)
      Color.lerp(_slow, _fast, i / (_toneSteps - 1))!,
  ];

  static const int _arrows = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final inner = side * (1 - 2 * _inset);
    final origin = Offset((size.width - inner) / 2, (size.height - inner) / 2);
    final route = [
      for (final p in layout.points)
        origin + Offset(p.dx * inner, p.dy * inner),
    ];
    // Thin, but never thinner than a hairline can render cleanly.
    final stroke = (side * 0.026).clamp(1.6, 2.4);

    _paintLine(canvas, route, stroke);
    _paintArrows(canvas, route, stroke);
    _paintStart(canvas, route.first, stroke);
    _paintFinish(canvas, route.last, stroke);
  }

  void _paintLine(Canvas canvas, List<Offset> route, double stroke) {
    Paint paint(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = color;

    if (!layout.hasHeat) {
      final path = Path()..moveTo(route.first.dx, route.first.dy);
      for (final o in route.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint(AppColors.primary));
      return;
    }

    // One path per tone, so a whole route is about ten strokes.
    final buckets = List<Path?>.filled(_toneSteps, null);
    for (var i = 1; i < route.length; i++) {
      final heat = (layout.heat[i - 1] + layout.heat[i]) / 2;
      final step = (heat * (_toneSteps - 1)).round();
      (buckets[step] ??= Path())
        ..moveTo(route[i - 1].dx, route[i - 1].dy)
        ..lineTo(route[i].dx, route[i].dy);
    }
    for (var step = 0; step < _toneSteps; step++) {
      final path = buckets[step];
      if (path != null) canvas.drawPath(path, paint(_tones[step]));
    }
  }

  /// Small chevrons evenly along the route, pointing the way it went.
  void _paintArrows(Canvas canvas, List<Offset> route, double stroke) {
    final lengths = <double>[0];
    for (var i = 1; i < route.length; i++) {
      lengths.add(lengths.last + (route[i] - route[i - 1]).distance);
    }
    final total = lengths.last;
    if (total < stroke * 14) return;

    final chevrons = Path();
    var segment = 1;
    for (var k = 1; k <= _arrows; k++) {
      final target = total * k / (_arrows + 1);
      while (segment < route.length - 1 && lengths[segment] < target) {
        segment++;
      }
      final a = route[segment - 1];
      final b = route[segment];
      final span = lengths[segment] - lengths[segment - 1];
      if (span <= 0) continue;
      final at = Offset.lerp(a, b, (target - lengths[segment - 1]) / span)!;
      final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      final back = stroke * 1.2;
      final wing = stroke * 1.5;
      chevrons
        ..moveTo(
          at.dx - back * cos + wing * sin,
          at.dy - back * sin - wing * cos,
        )
        ..lineTo(at.dx + back * cos, at.dy + back * sin)
        ..lineTo(
          at.dx - back * cos - wing * sin,
          at.dy - back * sin + wing * cos,
        );
    }
    canvas.drawPath(
      chevrons,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _paintStart(Canvas canvas, Offset at, double stroke) {
    canvas
      ..drawCircle(at, stroke * 2.1, Paint()..color = Colors.black)
      ..drawCircle(at, stroke * 1.7, Paint()..color = Colors.white)
      ..drawCircle(at, stroke * 0.8, Paint()..color = AppColors.primary);
  }

  /// A tiny chequered flag standing on the last point.
  void _paintFinish(Canvas canvas, Offset at, double stroke) {
    final cell = stroke * 1.35;
    const cols = 3;
    const rows = 2;
    final top = Offset(at.dx, at.dy - rows * cell - stroke * 1.6);
    canvas
      ..drawLine(
        at,
        top,
        Paint()
          ..color = Colors.white
          ..strokeWidth = stroke * 0.6
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(at, stroke * 1.1, Paint()..color = Colors.white);

    final cloth = Rect.fromLTWH(
      top.dx + stroke * 0.3,
      top.dy,
      cols * cell,
      rows * cell,
    );
    canvas.drawRect(cloth, Paint()..color = Colors.white);
    final dark = Paint()..color = Colors.black;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r + c).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(
              cloth.left + c * cell,
              cloth.top + r * cell,
              cell,
              cell,
            ),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(RouteThumbnailPainter old) =>
      !identical(old.layout, layout);
}
