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
/// The newest stretch is bright; older stretches settle to a calmer, steady
/// tone and never disappear. Segments are grouped into a few age bands and
/// each band is one path.
///
/// The paths are built once, in map-pixel space, and cached. Every frame the
/// camera moves (which, while following a rider, is every frame) only moves,
/// turns and scales that cached drawing to match the camera. Nothing is
/// projected again until the trails change or the zoom moves far enough to
/// need a sharper copy, so a long ride with many riders stays cheap to follow.
class TrailLayer extends StatefulWidget {
  const TrailLayer({super.key, required this.trails, required this.nowMs});

  final List<TrailStyle> trails;
  final int nowMs;

  @override
  State<TrailLayer> createState() => _TrailLayerState();
}

class _TrailLayerState extends State<TrailLayer> {
  final _TrailCache _cache = _TrailCache();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrailPainter(
          trails: widget.trails,
          nowMs: widget.nowMs,
          camera: MapCamera.of(context),
          cache: _cache,
        ),
      ),
    );
  }
}

/// One rider's paths, one per age band, in pixels relative to the cache's
/// origin at the cache's zoom.
class _CachedTrail {
  const _CachedTrail(this.color, this.bands);

  final Color color;
  final List<Path?> bands;
}

/// The trails as drawn at one zoom, relative to one origin.
class _TrailCache {
  List<TrailStyle>? trails;
  int? nowMs;
  double? zoom;
  LatLng? origin;
  Offset originPixels = Offset.zero;
  List<_CachedTrail> drawn = const [];

  bool isValidFor(List<TrailStyle> next, int now, double cameraZoom) =>
      nowMs == now &&
      zoom != null &&
      (cameraZoom - zoom!).abs() <= _TrailPainter._rebuildZoomDelta &&
      _same(trails, next);

  /// Trails are immutable and only replaced when they change, so comparing
  /// each rider's trail by identity is enough to know nothing moved.
  static bool _same(List<TrailStyle>? a, List<TrailStyle> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i].trail, b[i].trail) || a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.trails,
    required this.nowMs,
    required this.camera,
    required this.cache,
  });

  final List<TrailStyle> trails;
  final int nowMs;
  final MapCamera camera;
  final _TrailCache cache;

  /// Bands 0.._recentBands-1 are the recent stretch; the last band holds
  /// everything older.
  static const int _recentBands = 4;
  static const int _bands = _recentBands + 1;

  /// Width of each recent band's slice of time.
  static const int _bandSpanMs = 45000;

  static const double _strokeWidth = 3.5;

  /// Brightest and dimmest recent tone, and the steady tone of older path.
  /// The difference is deliberately slight: the whole ride stays easy to read.
  static const double _newestAlpha = 0.95;
  static const double _recentFloorAlpha = 0.84;
  static const double _olderAlpha = 0.7;

  /// The cached drawing is rebuilt once the zoom has moved this far from the
  /// zoom it was built at, so lines stay crisp after a big zoom in or out.
  static const double _rebuildZoomDelta = 1;

  /// Distance, in cache pixels, of the reference point used to work out how
  /// the camera has moved, turned and scaled the cached drawing.
  static const double _reference = 1000;

  @override
  void paint(Canvas canvas, Size size) {
    if (trails.isEmpty) return;
    if (!cache.isValidFor(trails, nowMs, camera.zoom)) _rebuild();
    final origin = cache.origin;
    final zoom = cache.zoom;
    if (origin == null || zoom == null || cache.drawn.isEmpty) return;

    // Where the cache's origin and a point a fixed distance east of it land
    // on screen now. Together they give the exact move, turn and scale from
    // the cached drawing to the screen.
    final atOrigin = camera.latLngToScreenOffset(origin);
    final east = camera.latLngToScreenOffset(
      camera.unprojectAtZoom(
        cache.originPixels + const Offset(_reference, 0),
        zoom,
      ),
    );
    final axis = east - atOrigin;
    final scale = axis.distance / _reference;
    if (scale <= 0) return;

    canvas
      ..save()
      ..translate(atOrigin.dx, atOrigin.dy)
      ..rotate(axis.direction)
      ..scale(scale);
    final width = _strokeWidth / scale;
    for (final trail in cache.drawn) {
      // Oldest first, so the freshest stretch is drawn on top.
      for (var band = _bands - 1; band >= 0; band--) {
        final path = trail.bands[band];
        if (path == null) continue;
        canvas.drawPath(
          path,
          _stroke(trail.color.withValues(alpha: _alphaFor(band)), width),
        );
      }
    }
    canvas.restore();
  }

  /// Projects every trail point once, at the current zoom, relative to the
  /// first point (which keeps the coordinates small and precise).
  void _rebuild() {
    final zoom = camera.zoom;
    LatLng? origin;
    for (final style in trails) {
      if (style.trail.points.isNotEmpty) {
        final first = style.trail.points.first.point;
        origin = LatLng(first.latitude, first.longitude);
        break;
      }
    }
    cache
      ..trails = trails
      ..nowMs = nowMs
      ..zoom = zoom
      ..origin = origin;
    if (origin == null) {
      cache.drawn = const [];
      return;
    }
    final originPixels = camera.projectAtZoom(origin, zoom);
    cache.originPixels = originPixels;

    Offset local(double latitude, double longitude) =>
        camera.projectAtZoom(LatLng(latitude, longitude), zoom) - originPixels;

    final drawn = <_CachedTrail>[];
    for (final style in trails) {
      final points = style.trail.points;
      if (points.length < 2) continue;
      final bands = List<Path?>.filled(_bands, null);
      Offset? previous = local(
        points.first.point.latitude,
        points.first.point.longitude,
      );
      for (var i = 1; i < points.length; i++) {
        final p = points[i];
        final current = local(p.point.latitude, p.point.longitude);
        if (p.startsSegment) {
          // The rider was away. Start again from here instead of inventing a
          // path across the gap.
          previous = current;
          continue;
        }
        final band = _bandFor(nowMs - p.timeMs);
        (bands[band] ??= Path())
          ..moveTo(previous!.dx, previous.dy)
          ..lineTo(current.dx, current.dy);
        previous = current;
      }
      drawn.add(_CachedTrail(style.color, bands));
    }
    cache.drawn = drawn;
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
