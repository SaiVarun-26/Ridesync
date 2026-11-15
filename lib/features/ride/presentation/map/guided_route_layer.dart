import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_colors.dart';
import '../../domain/geo_point.dart';
import '../../domain/guidance/route_guide.dart';

/// Draws the planned route of a guided ride under the riders' trails.
///
/// The route reads as a road to follow, not as another trail: a wide RideSync
/// purple line on a dark casing, with small chevrons pointing the way. The
/// stretch already ridden dims; the stretch up to the next turn is lifted a
/// little brighter; the next turn and the destination are marked.
///
/// Like the trail layer, the line is projected once into map pixels and
/// cached. Each frame only moves, turns and scales that drawing to the
/// camera; it is rebuilt when the zoom moves a whole level, and the ridden /
/// ahead split is rebuilt when progress changes (about once a second).
class GuidedRouteLayer extends StatefulWidget {
  const GuidedRouteLayer({
    super.key,
    required this.guide,
    this.progressMeters,
    this.activeEndMeters,
    this.nextTurn,
    this.reveal = 1,
    this.hasArrived = false,
  });

  final RouteGuide guide;

  /// How far along the route the rider is; `null` in a preview.
  final double? progressMeters;

  /// End of the highlighted stretch ahead.
  final double? activeEndMeters;

  /// Where the next turn is, to mark it.
  final GeoPoint? nextTurn;

  /// Share of the route drawn (0–1), for the preview's draw-in.
  final double reveal;

  /// Shows the destination as reached.
  final bool hasArrived;

  @override
  State<GuidedRouteLayer> createState() => _GuidedRouteLayerState();
}

class _GuidedRouteLayerState extends State<GuidedRouteLayer> {
  final _RouteCache _cache = _RouteCache();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RoutePainter(
          guide: widget.guide,
          progress: widget.progressMeters,
          activeEnd: widget.activeEndMeters,
          nextTurn: widget.nextTurn,
          reveal: widget.reveal,
          arrived: widget.hasArrived,
          camera: MapCamera.of(context),
          cache: _cache,
        ),
      ),
    );
  }
}

class _RouteCache {
  RouteGuide? guide;
  double? zoom;
  LatLng? origin;
  Offset originPixels = Offset.zero;

  /// Every vertex in cache pixels.
  List<Offset> points = const [];

  /// Chevrons: position, direction (radians) and distance along the route.
  List<(Offset, double, double)> chevrons = const [];

  Path? full;
  ui.PathMetric? fullMetric;

  double? splitAt;
  double? activeEnd;
  Path? done;
  Path? ahead;
  Path? active;
  Path? arrows;
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.guide,
    required this.progress,
    required this.activeEnd,
    required this.nextTurn,
    required this.reveal,
    required this.arrived,
    required this.camera,
    required this.cache,
  });

  final RouteGuide guide;
  final double? progress;
  final double? activeEnd;
  final GeoPoint? nextTurn;
  final double reveal;
  final bool arrived;
  final MapCamera camera;
  final _RouteCache cache;

  static const double _rebuildZoomDelta = 1;
  static const double _reference = 1000;

  static const double _lineWidth = 6;
  static const double _casingWidth = 10;
  static const double _chevronSpacing = 120;
  static const double _chevronSize = 3.2;

  static const Color _casing = Color(0xD9000000);
  static final Color _done = AppColors.primary.withValues(alpha: 0.32);
  static final Color _active = Color.lerp(
    AppColors.primary,
    Colors.white,
    0.3,
  )!;
  static const Color _chevron = Color(0xE6FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (!guide.isUsable) return;
    if (cache.guide != guide ||
        cache.zoom == null ||
        (camera.zoom - cache.zoom!).abs() > _rebuildZoomDelta) {
      _rebuild();
    }
    final origin = cache.origin;
    final zoom = cache.zoom;
    if (origin == null || zoom == null) return;

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
    final px = 1 / scale;

    if (progress == null) {
      _paintPreview(canvas, px);
    } else {
      _paintLive(canvas, px);
    }
    canvas.restore();
    _paintMarkers(canvas);
  }

  void _paintPreview(Canvas canvas, double px) {
    final full = cache.full;
    if (full == null) return;
    Path path = full;
    if (reveal < 1) {
      final metric = cache.fullMetric;
      if (metric == null) return;
      path = metric.extractPath(0, metric.length * reveal.clamp(0.0, 1.0));
    }
    canvas
      ..drawPath(path, _stroke(_casing, _casingWidth * px))
      ..drawPath(path, _stroke(AppColors.primary, _lineWidth * px));
    if (reveal >= 1) _ensureSplit(0, null);
    final arrows = cache.arrows;
    if (reveal >= 1 && arrows != null) {
      canvas.drawPath(arrows, _stroke(_chevron, 1.8 * px));
    }
  }

  void _paintLive(Canvas canvas, double px) {
    _ensureSplit(progress!, activeEnd);
    final done = cache.done;
    final ahead = cache.ahead;
    final active = cache.active;
    final arrows = cache.arrows;
    if (done != null) canvas.drawPath(done, _stroke(_done, _lineWidth * px));
    if (ahead != null) {
      canvas
        ..drawPath(ahead, _stroke(_casing, _casingWidth * px))
        ..drawPath(ahead, _stroke(AppColors.primary, _lineWidth * px));
    }
    if (active != null) {
      canvas.drawPath(active, _stroke(_active, _lineWidth * px));
    }
    if (arrows != null) canvas.drawPath(arrows, _stroke(_chevron, 1.8 * px));
  }

  /// Start, next turn and destination, at a fixed size on screen.
  void _paintMarkers(Canvas canvas) {
    Offset screen(GeoPoint p) =>
        camera.latLngToScreenOffset(LatLng(p.latitude, p.longitude));

    if (progress == null || progress! < 30) {
      final start = screen(guide.geometry.start);
      canvas
        ..drawCircle(start, 7, Paint()..color = AppColors.background)
        ..drawCircle(
          start,
          5.5,
          Paint()
            ..color = AppColors.textPrimary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
    }

    final turn = nextTurn;
    if (turn != null && !arrived) {
      final at = screen(turn);
      canvas
        ..drawCircle(at, 7, Paint()..color = AppColors.primary)
        ..drawCircle(at, 3.5, Paint()..color = AppColors.textPrimary);
    }

    final end = screen(guide.geometry.end);
    canvas
      ..drawCircle(end, 13, Paint()..color = AppColors.background)
      ..drawCircle(end, 11, Paint()..color = AppColors.primary)
      ..drawCircle(
        end,
        11,
        Paint()
          ..color = AppColors.textPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    if (arrived) {
      final check = Path()
        ..moveTo(end.dx - 4.5, end.dy + 0.2)
        ..lineTo(end.dx - 1.2, end.dy + 3.5)
        ..lineTo(end.dx + 5, end.dy - 3.5);
      canvas.drawPath(check, _stroke(AppColors.textPrimary, 2.4));
    } else {
      canvas.drawCircle(end, 3.5, Paint()..color = AppColors.textPrimary);
    }
  }

  void _rebuild() {
    final zoom = camera.zoom;
    final geometry = guide.geometry;
    final first = geometry.start;
    final origin = LatLng(first.latitude, first.longitude);
    final originPixels = camera.projectAtZoom(origin, zoom);
    final points = <Offset>[
      for (final p in geometry.points)
        camera.projectAtZoom(LatLng(p.latitude, p.longitude), zoom) -
            originPixels,
    ];

    final full = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      full.lineTo(points[i].dx, points[i].dy);
    }

    // Chevrons at an even spacing on screen, each pointing along the route.
    final chevrons = <(Offset, double, double)>[];
    var carried = _chevronSpacing / 2;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final segment = b - a;
      final length = segment.distance;
      if (length <= 0) continue;
      final alongA = geometry.alongAt(i);
      final alongB = geometry.alongAt(i + 1);
      var at = carried;
      while (at <= length) {
        final t = at / length;
        chevrons.add((
          a + segment * t,
          segment.direction,
          alongA + (alongB - alongA) * t,
        ));
        at += _chevronSpacing;
      }
      carried = at - length;
    }

    final metrics = full.computeMetrics().toList();
    cache
      ..guide = guide
      ..zoom = zoom
      ..origin = origin
      ..originPixels = originPixels
      ..points = points
      ..chevrons = chevrons
      ..full = full
      ..fullMetric = metrics.isEmpty ? null : metrics.first
      ..splitAt = null
      ..activeEnd = null;
  }

  /// Rebuilds the ridden, ahead and highlighted paths when progress moved.
  void _ensureSplit(double split, double? activeEndMeters) {
    if (cache.splitAt == split && cache.activeEnd == activeEndMeters) return;
    final total = guide.lengthMeters;
    cache
      ..splitAt = split
      ..activeEnd = activeEndMeters
      ..done = split > 0 ? _pathBetween(0, split) : null
      ..ahead = split < total ? _pathBetween(split, total) : null
      ..active = activeEndMeters != null && activeEndMeters > split
          ? _pathBetween(split, activeEndMeters)
          : null
      ..arrows = _arrowsAfter(split + 12);
  }

  Path? _pathBetween(double from, double to) {
    final geometry = guide.geometry;
    final points = cache.points;
    if (points.length < 2 || to <= from) return null;
    Offset pointAt(double along) {
      final i = geometry.segmentAt(along);
      final a = geometry.alongAt(i);
      final b = geometry.alongAt(i + 1);
      final t = b > a ? ((along - a) / (b - a)).clamp(0.0, 1.0) : 0.0;
      return Offset.lerp(points[i], points[i + 1], t)!;
    }

    final start = pointAt(from);
    final path = Path()..moveTo(start.dx, start.dy);
    final first = geometry.segmentAt(from) + 1;
    final last = geometry.segmentAt(to);
    for (var i = first; i <= last; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final end = pointAt(to);
    path.lineTo(end.dx, end.dy);
    return path;
  }

  Path? _arrowsAfter(double along) {
    final arrows = Path();
    var any = false;
    for (final (at, direction, chevronAlong) in cache.chevrons) {
      if (chevronAlong <= along) continue;
      any = true;
      final ux = math.cos(direction);
      final uy = math.sin(direction);
      // A small open chevron, pointing the way the route goes.
      final tip = at + Offset(ux, uy) * _chevronSize;
      final back = at - Offset(ux, uy) * _chevronSize;
      final side = Offset(-uy, ux) * _chevronSize;
      arrows
        ..moveTo((back + side).dx, (back + side).dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo((back - side).dx, (back - side).dy);
    }
    return any ? arrows : null;
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.camera != camera ||
      old.guide != guide ||
      old.progress != progress ||
      old.activeEnd != activeEnd ||
      old.nextTurn != nextTurn ||
      old.reveal != reveal ||
      old.arrived != arrived;
}
