import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../domain/live/rider_trail.dart';

/// One rider's trail and the color to draw it in.
class TrailStyle {
  const TrailStyle({required this.trail, required this.color});

  final RiderTrail trail;
  final Color color;
}

/// Paints each rider's recent path in their color, fading with age: the
/// newest stretch is bright with a soft glow, older stretches dissolve.
///
/// Segments are grouped into a few age bands and each band is one path, so
/// 25 riders cost a few dozen draw calls rather than thousands.
class TrailLayer extends StatelessWidget {
  const TrailLayer({super.key, required this.trails, required this.nowMs});

  final List<TrailStyle> trails;
  final int nowMs;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrailPainter(
        trails: trails,
        nowMs: nowMs,
        camera: MapCamera.of(context),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.trails,
    required this.nowMs,
    required this.camera,
  });

  final List<TrailStyle> trails;
  final int nowMs;
  final MapCamera camera;

  static const int _bands = 6;
  static const double _strokeWidth = 3.5;
  static const double _glowWidth = 9;
  static const double _glowBlur = 4;
  static const double _maxAlpha = 0.9;
  static const double _glowAlpha = 0.3;

  /// Consecutive points further apart in time than this are not joined.
  static const int _gapMs = 120000;

  @override
  void paint(Canvas canvas, Size size) {
    final window = RiderTrail.window.inMilliseconds;
    for (final style in trails) {
      final points = style.trail.points;
      if (points.length < 2) continue;

      final bands = List<Path?>.filled(_bands, null);
      var previous = _offset(points.first.point.latitude,
          points.first.point.longitude);
      var previousTimeMs = points.first.timeMs;
      for (var i = 1; i < points.length; i++) {
        final p = points[i];
        final current = _offset(p.point.latitude, p.point.longitude);
        final gap = p.timeMs - previousTimeMs > _gapMs;
        previousTimeMs = p.timeMs;
        if (gap) {
          // The rider was away (backgrounded, no signal). Resume the trail
          // from here rather than inventing a path across the gap.
          previous = current;
          continue;
        }
        final age = (nowMs - p.timeMs).clamp(0, window) / window;
        final band = (age * _bands).floor().clamp(0, _bands - 1);
        (bands[band] ??= Path())
          ..moveTo(previous.dx, previous.dy)
          ..lineTo(current.dx, current.dy);
        previous = current;
      }

      final newest = bands.first;
      if (newest != null) {
        canvas.drawPath(
          newest,
          _stroke(style.color.withValues(alpha: _glowAlpha), _glowWidth)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowBlur),
        );
      }
      for (var band = 0; band < _bands; band++) {
        final path = bands[band];
        if (path == null) continue;
        final alpha = _maxAlpha * (1 - band / _bands);
        canvas.drawPath(
          path,
          _stroke(style.color.withValues(alpha: alpha), _strokeWidth),
        );
      }
    }
  }

  Offset _offset(double latitude, double longitude) =>
      camera.latLngToScreenOffset(LatLng(latitude, longitude));

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.nowMs != nowMs ||
      !identical(oldDelegate.trails, trails);
}
