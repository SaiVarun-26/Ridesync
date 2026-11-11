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

/// Paints each rider's whole ridden path in their color.
///
/// The newest stretch is bright and glows softly; older stretches settle to a
/// calmer, steady tone and never disappear. Segments are grouped into a few
/// age bands and each band is one path, and only the part of the path that is
/// near the screen is built, so a long ride with many riders stays cheap.
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

  /// Bands 0.._recentBands-1 are the recent stretch; the last band holds
  /// everything older.
  static const int _recentBands = 4;
  static const int _bands = _recentBands + 1;

  /// Width of each recent band's slice of time.
  static const int _bandSpanMs = 45000;

  static const double _strokeWidth = 3.5;
  static const double _glowWidth = 9;
  static const double _glowBlur = 4;
  static const double _glowAlpha = 0.32;

  /// Brightest and dimmest recent tone, and the steady tone of older path.
  static const double _newestAlpha = 0.95;
  static const double _recentFloorAlpha = 0.7;
  static const double _olderAlpha = 0.5;

  /// How far past the screen edge points are still included, as a fraction of
  /// the visible size, so lines run cleanly off the screen.
  static const double _cullMargin = 0.15;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = camera.visibleBounds;
    final latPad = (bounds.north - bounds.south) * _cullMargin;
    final lngPad = (bounds.east - bounds.west) * _cullMargin;
    final south = bounds.south - latPad;
    final north = bounds.north + latPad;
    final west = bounds.west - lngPad;
    final east = bounds.east + lngPad;

    bool near(double lat, double lng) =>
        lat >= south && lat <= north && lng >= west && lng <= east;

    for (final style in trails) {
      final points = style.trail.points;
      if (points.length < 2) continue;

      final bands = List<Path?>.filled(_bands, null);
      var previousNear = near(
        points.first.point.latitude,
        points.first.point.longitude,
      );
      Offset? previousOffset;
      for (var i = 1; i < points.length; i++) {
        final p = points[i];
        final currentNear = near(p.point.latitude, p.point.longitude);
        if (p.startsSegment) {
          // The rider was away. Start again from here instead of inventing a
          // path across the gap.
          previousNear = currentNear;
          previousOffset = null;
          continue;
        }
        if (previousNear || currentNear) {
          previousOffset ??= _offset(
            points[i - 1].point.latitude,
            points[i - 1].point.longitude,
          );
          final current = _offset(p.point.latitude, p.point.longitude);
          final band = _bandFor(nowMs - p.timeMs);
          (bands[band] ??= Path())
            ..moveTo(previousOffset.dx, previousOffset.dy)
            ..lineTo(current.dx, current.dy);
          previousOffset = current;
        } else {
          previousOffset = null;
        }
        previousNear = currentNear;
      }

      final newest = bands.first;
      if (newest != null) {
        canvas.drawPath(
          newest,
          _stroke(style.color.withValues(alpha: _glowAlpha), _glowWidth)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowBlur),
        );
      }
      // Oldest first, so the freshest stretch is drawn on top.
      for (var band = _bands - 1; band >= 0; band--) {
        final path = bands[band];
        if (path == null) continue;
        canvas.drawPath(
          path,
          _stroke(style.color.withValues(alpha: _alphaFor(band)), _strokeWidth),
        );
      }
    }
  }

  static int _bandFor(int ageMs) {
    final band = ageMs <= 0 ? 0 : ageMs ~/ _bandSpanMs;
    return band >= _recentBands ? _bands - 1 : band;
  }

  static double _alphaFor(int band) {
    if (band >= _recentBands) return _olderAlpha;
    final t = band / (_recentBands - 1);
    return _newestAlpha + (_recentFloorAlpha - _newestAlpha) * t;
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
