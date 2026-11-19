import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../ride/domain/geo_point.dart';

/// Something that happened at one place on the ride, marked on a [MiniRoute].
class MiniRouteEvent {
  const MiniRouteEvent({required this.point, required this.icon, this.badge});

  final GeoPoint point;
  final IconData icon;

  /// A short figure beside the icon ("68 km/h"), if any.
  final String? badge;
}

/// A small drawing of the ride's route, for a card: the line in the rider's
/// colour with arrows showing the way it was ridden, the start and the finish,
/// and each [events] marked by an icon whose pointer lands on the exact spot.
class MiniRoute extends StatelessWidget {
  const MiniRoute({
    super.key,
    required this.points,
    required this.color,
    this.events = const [],
    this.height = 120,
  });

  final List<GeoPoint> points;
  final Color color;
  final List<MiniRouteEvent> events;
  final double height;

  /// The point [meters] along [points], or `null` without a route.
  static GeoPoint? pointAt(List<GeoPoint> points, double meters) {
    if (points.isEmpty) return null;
    var walked = 0.0;
    for (var i = 1; i < points.length; i++) {
      final step = points[i - 1].distanceMetersTo(points[i]);
      if (walked + step >= meters) {
        final t = step <= 0 ? 0.0 : (meters - walked) / step;
        final a = points[i - 1];
        final b = points[i];
        return GeoPoint(
          latitude: a.latitude + (b.latitude - a.latitude) * t,
          longitude: a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      walked += step;
    }
    return points.last;
  }

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    return Semantics(
      image: true,
      label: 'Route drawing',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            size: Size.infinite,
            painter: _MiniRoutePainter(
              points: points,
              color: color,
              events: events,
              labelStyle: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniRoutePainter extends CustomPainter {
  _MiniRoutePainter({
    required this.points,
    required this.color,
    required this.events,
    required this.labelStyle,
  });

  final List<GeoPoint> points;
  final Color color;
  final List<MiniRouteEvent> events;
  final TextStyle? labelStyle;

  static const double _pad = 22;
  static const double _badgeRadius = 11;
  static const double _badgeLift = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final project = _projection(size);
    final screen = [for (final p in points) project(p)];

    // The route: a dark casing under the rider's colour.
    final path = Path()..moveTo(screen.first.dx, screen.first.dy);
    for (final s in screen.skip(1)) {
      path.lineTo(s.dx, s.dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black.withValues(alpha: 0.55),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );

    _paintArrows(canvas, path);

    // Start: the rider's colour ringed in white. Finish: a chequered square.
    canvas
      ..drawCircle(screen.first, 6, Paint()..color = Colors.white)
      ..drawCircle(screen.first, 4, Paint()..color = color);
    _paintFinish(canvas, screen.last);

    for (final event in events) {
      _paintEvent(canvas, size, project(event.point), event);
    }
  }

  /// Fits the route into [size], north up, keeping its shape.
  Offset Function(GeoPoint) _projection(Size size) {
    var south = double.infinity;
    var north = -double.infinity;
    var west = double.infinity;
    var east = -double.infinity;
    for (final p in points) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    final midLat = (north + south) / 2 * math.pi / 180;
    final k = math.cos(midLat);
    final spanX = math.max((east - west) * k, 1e-6);
    final spanY = math.max(north - south, 1e-6);
    // Room above for the event badges.
    final top = events.isEmpty ? _pad : _pad + _badgeLift * 0.6;
    final width = size.width - _pad * 2;
    final height = size.height - top - _pad;
    final scale = math.min(width / spanX, height / spanY);
    final offsetX = _pad + (width - spanX * scale) / 2;
    final offsetY = top + (height - spanY * scale) / 2;
    return (p) => Offset(
      offsetX + (p.longitude - west) * k * scale,
      offsetY + (north - p.latitude) * scale,
    );
  }

  /// Small chevrons along the line, pointing the way it was ridden.
  void _paintArrows(Canvas canvas, Path path) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.9);
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      if (length < 60) continue;
      final count = math.min(5, (length / 60).floor());
      for (var i = 1; i <= count; i++) {
        final tangent = metric.getTangentForOffset(length * i / (count + 1));
        if (tangent == null) continue;
        final d = tangent.vector;
        final n = Offset(-d.dy, d.dx);
        final tip = tangent.position + d * 3;
        canvas.drawPath(
          Path()
            ..moveTo((tip - d * 4 + n * 3.2).dx, (tip - d * 4 + n * 3.2).dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo((tip - d * 4 - n * 3.2).dx, (tip - d * 4 - n * 3.2).dy),
          paint,
        );
      }
    }
  }

  void _paintFinish(Canvas canvas, Offset at) {
    const cell = 3.0;
    final rect = Rect.fromCenter(center: at, width: cell * 4, height: cell * 4);
    canvas
      ..drawRect(rect.inflate(1.5), Paint()..color = Colors.white)
      ..drawRect(rect, Paint()..color = Colors.white);
    final dark = Paint()..color = AppColors.background;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        if ((r + c).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(rect.left + c * cell, rect.top + r * cell, cell, cell),
            dark,
          );
        }
      }
    }
  }

  /// A badge with the event's icon (and figure) above the spot, and an arrow
  /// from it down to exactly where it happened.
  void _paintEvent(Canvas canvas, Size size, Offset at, MiniRouteEvent event) {
    final label = event.badge == null
        ? null
        : (TextPainter(
            text: TextSpan(
              text: event.badge,
              style: (labelStyle ?? const TextStyle()).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout());
    final width =
        _badgeRadius * 2 + (label == null ? 0 : label.width + 8);
    final above = at.dy - _badgeLift - _badgeRadius >= 2;
    final centerY = above ? at.dy - _badgeLift : at.dy + _badgeLift;
    final left = (at.dx - width / 2)
        .clamp(4.0, math.max(4.0, size.width - width - 4))
        .toDouble();
    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, centerY - _badgeRadius, width, _badgeRadius * 2),
      const Radius.circular(_badgeRadius),
    );

    // The pointer, from the badge to the spot, with its head on the spot.
    final from = Offset(
      at.dx
          .clamp(badge.left + _badgeRadius, badge.right - _badgeRadius)
          .toDouble(),
      above ? badge.bottom : badge.top,
    );
    final line = at - from;
    final length = line.distance;
    final pointer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    if (length > 6) {
      final d = line / length;
      final n = Offset(-d.dy, d.dx);
      final tip = at - d * 5;
      canvas
        ..drawLine(from, tip, pointer)
        ..drawPath(
          Path()
            ..moveTo((tip - d * 5 + n * 3.5).dx, (tip - d * 5 + n * 3.5).dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo((tip - d * 5 - n * 3.5).dx, (tip - d * 5 - n * 3.5).dy),
          pointer,
        );
    }
    canvas
      ..drawCircle(at, 4, Paint()..color = Colors.white)
      ..drawCircle(at, 2.4, Paint()..color = color)
      ..drawRRect(badge, Paint()..color = AppColors.surface)
      ..drawRRect(
        badge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color,
      );

    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(event.icon.codePoint),
        style: TextStyle(
          fontFamily: event.icon.fontFamily,
          package: event.icon.fontPackage,
          fontSize: 14,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(
      canvas,
      Offset(
        badge.left + _badgeRadius - icon.width / 2,
        centerY - icon.height / 2,
      ),
    );
    label?.paint(
      canvas,
      Offset(badge.left + _badgeRadius * 2, centerY - label.height / 2),
    );
  }

  @override
  bool shouldRepaint(_MiniRoutePainter old) =>
      !identical(old.points, points) ||
      old.color != color ||
      old.events != events;
}
