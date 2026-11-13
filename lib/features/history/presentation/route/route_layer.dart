import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'heat_palette.dart';
import 'route_scene.dart';

/// Draws a ride's routes on the map: each rider's path coloured by speed,
/// direction arrows at an even spacing on the screen, and a highlight for the
/// rider the viewer has picked.
///
/// Meant to sit among a [FlutterMap]'s children. It follows the map's camera,
/// so panning, zooming and rotating all keep it in place.
class RouteLayer extends StatelessWidget {
  const RouteLayer({
    super.key,
    required this.scene,
    required this.selectedUid,
    required this.reveal,
    required this.heat,
    required this.arrowsOpacity,
  });

  final RouteScene scene;

  /// The rider whose route is highlighted; everyone else is dimmed. `null`
  /// shows every rider equally.
  final String? selectedUid;

  /// How much of each route is drawn, 0 to 1, from the start.
  final Animation<double> reveal;

  /// How much the speed colours have replaced each rider's own colour, 0 to
  /// 1. The route is first drawn in the rider's colour; the heat then fades in.
  final Animation<double> heat;

  /// How visible the direction arrows are, 0 to 1.
  final Animation<double> arrowsOpacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RoutePainter(
            scene: scene,
            camera: MapCamera.of(context),
            selectedUid: selectedUid,
            reveal: reveal,
            heat: heat,
            arrowsOpacity: arrowsOpacity,
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.scene,
    required this.camera,
    required this.selectedUid,
    required this.reveal,
    required this.heat,
    required this.arrowsOpacity,
  }) : super(repaint: Listenable.merge([reveal, heat, arrowsOpacity]));

  final RouteScene scene;
  final MapCamera camera;
  final String? selectedUid;
  final Animation<double> reveal;
  final Animation<double> heat;
  final Animation<double> arrowsOpacity;

  static const int _colorSteps = 40;
  static final List<Color> _heat = HeatPalette.steps(_colorSteps);

  static const double _lineWidth = 4.5;
  static const double _casingWidth = 8;
  static const double _laneOffset = 2.6;
  static const double _arrowSpacing = 92;
  static const double _arrowSize = 5;
  static const double _dimmedAlpha = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = reveal.value;
    if (progress <= 0) return;
    final transform = scene.transformFor(camera);
    final viewport = (Offset.zero & size).inflate(80);

    // Dimmed riders first, the highlighted one on top.
    final riders = [...scene.riders]
      ..sort((a, b) {
        final aSelected = a.uid == selectedUid ? 1 : 0;
        final bSelected = b.uid == selectedUid ? 1 : 0;
        return aSelected - bSelected;
      });

    for (final rider in riders) {
      final selected = rider.uid == selectedUid;
      final dimmed = selectedUid != null && !selected;
      final route = ProjectedRoute.project(
        rider,
        transform,
        laneOffset: _laneOffset,
      );
      if (route.length < 2) continue;
      _paintRoute(
        canvas,
        route,
        viewport: viewport,
        progress: progress,
        selected: selected,
        alpha: dimmed ? _dimmedAlpha : 1,
        withArrows: !dimmed,
      );
    }
  }

  void _paintRoute(
    Canvas canvas,
    ProjectedRoute route, {
    required Rect viewport,
    required double progress,
    required bool selected,
    required double alpha,
    required bool withArrows,
  }) {
    final speeds = route.rider.heat;
    final drawLength = route.totalLength * progress;
    final heatMix = heat.value;

    final casing = Path();
    final solid = Path();
    final buckets = speeds == null
        ? null
        : List<Path?>.filled(_colorSteps, null);

    for (var i = 1; i < route.length; i++) {
      if (route.along[i - 1] >= drawLength) break;
      var x1 = route.xs[i];
      var y1 = route.ys[i];
      final x0 = route.xs[i - 1];
      final y0 = route.ys[i - 1];
      if (route.along[i] > drawLength) {
        // The drawing front is inside this segment.
        final span = route.along[i] - route.along[i - 1];
        final t = span == 0 ? 0.0 : (drawLength - route.along[i - 1]) / span;
        x1 = x0 + (x1 - x0) * t;
        y1 = y0 + (y1 - y0) * t;
      }
      if (!_visible(viewport, x0, y0, x1, y1)) continue;

      casing
        ..moveTo(x0, y0)
        ..lineTo(x1, y1);
      solid
        ..moveTo(x0, y0)
        ..lineTo(x1, y1);
      if (buckets != null) {
        final a = speeds![route.source[i - 1]];
        final b = speeds[route.source[i]];
        final step = (((a + b) / 2) * (_colorSteps - 1)).round();
        (buckets[step] ??= Path())
          ..moveTo(x0, y0)
          ..lineTo(x1, y1);
      }
    }

    canvas.drawPath(
      casing,
      _stroke(
        selected
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.55 * alpha),
        _casingWidth,
      ),
    );

    // The rider's own colour first; once the heat is fully in, it is hidden
    // underneath and need not be drawn.
    if (buckets == null || heatMix < 1) {
      canvas.drawPath(
        solid,
        _stroke(route.rider.color.withValues(alpha: alpha), _lineWidth),
      );
    }
    if (buckets != null && heatMix > 0) {
      for (var step = 0; step < _colorSteps; step++) {
        final path = buckets[step];
        if (path == null) continue;
        canvas.drawPath(
          path,
          _stroke(_heat[step].withValues(alpha: alpha * heatMix), _lineWidth),
        );
      }
    }

    final arrowAlpha = arrowsOpacity.value * alpha;
    if (withArrows && arrowAlpha > 0.01) {
      _paintArrows(canvas, route, viewport, drawLength, arrowAlpha);
    }
  }

  /// Chevrons along the route at an even spacing on the screen, pointing the
  /// way the rider went. Spacing is measured in screen pixels, so zooming in
  /// shows more of them and zooming out fewer, never a crowd.
  void _paintArrows(
    Canvas canvas,
    ProjectedRoute route,
    Rect viewport,
    double drawLength,
    double alpha,
  ) {
    final outline = Path();
    final fill = Path();
    var next = _arrowSpacing / 2;
    for (var i = 1; i < route.length; i++) {
      final start = route.along[i - 1];
      final end = route.along[i];
      if (start > drawLength) break;
      final x0 = route.xs[i - 1];
      final y0 = route.ys[i - 1];
      final dx = route.xs[i] - x0;
      final dy = route.ys[i] - y0;
      final length = end - start;
      if (length <= 0) continue;
      final angle = math.atan2(dy, dx);
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      while (next <= end && next <= drawLength) {
        final t = (next - start) / length;
        final x = x0 + dx * t;
        final y = y0 + dy * t;
        next += _arrowSpacing;
        if (!viewport.contains(Offset(x, y))) continue;
        // A chevron pointing along (cos, sin).
        void chevron(Path path) {
          const back = _arrowSize * 0.8;
          const wing = _arrowSize;
          path
            ..moveTo(x - back * cos + wing * sin, y - back * sin - wing * cos)
            ..lineTo(x + back * cos, y + back * sin)
            ..lineTo(x - back * cos - wing * sin, y - back * sin + wing * cos);
        }

        chevron(outline);
        chevron(fill);
      }
    }
    canvas
      ..drawPath(
        outline,
        _stroke(Colors.black.withValues(alpha: 0.7 * alpha), 4.6),
      )
      ..drawPath(
        fill,
        _stroke(Colors.white.withValues(alpha: 0.95 * alpha), 2.2),
      );
  }

  static bool _visible(Rect view, double x0, double y0, double x1, double y1) {
    return view.contains(Offset(x0, y0)) || view.contains(Offset(x1, y1));
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.camera != camera ||
      old.selectedUid != selectedUid ||
      !identical(old.scene, scene);
}

/// A speed legend: the colour bar from slow to fast with its range.
class SpeedLegend extends StatelessWidget {
  const SpeedLegend({super.key, required this.lowText, required this.highText});

  final String lowText;
  final String highText;

  static final List<Color> _steps = HeatPalette.steps(16);

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: AppColors.textSecondary);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // A row of flat colour steps, slow to fast.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    for (final color in _steps)
                      Expanded(child: ColoredBox(color: color)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lowText, style: label),
                const SizedBox(width: AppSpacing.lg),
                Text(highText, style: label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
