import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'marker_interpolator.dart';

/// Paints every rider as a flat dot: translucent disc, colored center, and a
/// subtle outer ring, with a small wedge showing the direction of travel.
/// Resting markers float very slightly and send out a soft ring every few
/// seconds; arriving ones spring up and ring once.
///
/// Positions come from the shared [MarkerInterpolator] and are repainted on
/// every [frames] tick, without rebuilding any widgets. The layer sits on its
/// own repaint boundary, so a marker frame never repaints the map tiles or
/// trails underneath.
class LiveMarkerLayer extends StatelessWidget {
  const LiveMarkerLayer({
    super.key,
    required this.interpolator,
    required this.frames,
    required this.clock,
  });

  final MarkerInterpolator interpolator;

  /// Ticks once per animation frame.
  final Listenable frames;

  /// Current animation time.
  final Duration Function() clock;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _MarkerPainter(
          interpolator: interpolator,
          camera: MapCamera.of(context),
          clock: clock,
          repaint: frames,
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter({
    required this.interpolator,
    required this.camera,
    required this.clock,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final MarkerInterpolator interpolator;
  final MapCamera camera;
  final Duration Function() clock;

  static const double _dotRadius = 6.5;
  static const double _ringRadius = 10.5;
  static const double _glowRadius = 16;
  static const double _ringWidth = 1.5;
  static const double _backingWidth = 2.5;
  static const double _glowAlpha = 0.16;
  static const double _ringAlpha = 0.55;
  static const double _wedgeNear = 13;
  static const double _wedgeFar = 21;
  static const double _wedgeHalfWidth = 5;
  static const double _wedgeAlpha = 0.85;

  /// How far the pulse ring travels past the outer ring, and how strong it
  /// starts.
  static const double _pulseSpread = 16;
  static const double _pulseAlpha = 0.45;

  /// The idle float: the dot lifts by at most this many pixels and the halo
  /// grows by at most this fraction.
  static const double _floatLift = 1.2;
  static const double _haloBreath = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    final frames = interpolator.sample(clock());
    // Draw this rider last so they are never hidden under the group.
    frames.sort((a, b) => (a.isMe ? 1 : 0) - (b.isMe ? 1 : 0));
    for (final frame in frames) {
      final center = camera.latLngToScreenOffset(
        LatLng(frame.point.latitude, frame.point.longitude),
      );
      _paintRider(canvas, center, frame);
    }
  }

  void _paintRider(Canvas canvas, Offset center, MarkerFrame frame) {
    final opacity = frame.opacity;
    final color = frame.color;

    // The soft ring sits on the rider's true position, outside the scale and
    // float, so it always radiates from exactly where they are.
    final pulse = frame.pulse;
    if (pulse != null) _paintPulse(canvas, center, pulse, color, opacity);

    // A rider arriving springs up from small; a rider leaving shrinks away.
    // Riders at rest take the plain path.
    final scale = frame.scale;
    if (scale != 1) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..scale(scale)
        ..translate(-center.dx, -center.dy);
      _paintRiderBody(canvas, center, frame, opacity, color);
      canvas.restore();
      return;
    }
    _paintRiderBody(canvas, center, frame, opacity, color);
  }

  /// One soft ring expanding from the marker and fading as it goes. Flat
  /// colour, no blur: it reads as a ripple, not a glow.
  void _paintPulse(
    Canvas canvas,
    Offset center,
    double progress,
    Color color,
    double opacity,
  ) {
    final t = AppMotion.curve.transform(progress);
    final fade = (1 - progress) * (1 - progress);
    canvas.drawCircle(
      center,
      _ringRadius + _pulseSpread * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringWidth
        ..color = color.withValues(alpha: _pulseAlpha * fade * opacity),
    );
  }

  void _paintRiderBody(
    Canvas canvas,
    Offset center,
    MarkerFrame frame,
    double opacity,
    Color color,
  ) {
    // The halo breathes very slightly with the idle float.
    canvas.drawCircle(
      center,
      _glowRadius * (1 + _haloBreath * frame.float),
      // A flat translucent disc, only enough to lift the dot off the map.
      Paint()..color = color.withValues(alpha: _glowAlpha * opacity),
    );
    // The dot itself floats a hair above its true position.
    final dot = center.translate(0, -_floatLift * (frame.float + 1) / 2);

    final heading = frame.headingDegrees;
    if (heading != null) {
      // The map may be rotated: add its rotation to get the on-screen
      // direction. While following, this is exactly "up", so this rider's
      // wedge always points forward and stays upright as the map turns.
      _paintWedge(canvas, dot, heading + camera.rotation, color, opacity);
    }

    canvas
      ..drawCircle(
        dot,
        _ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringWidth
          ..color = color.withValues(alpha: _ringAlpha * opacity),
      )
      ..drawCircle(
        dot,
        _dotRadius + _backingWidth,
        Paint()..color = AppColors.background.withValues(alpha: opacity),
      )
      ..drawCircle(
        dot,
        _dotRadius,
        Paint()..color = color.withValues(alpha: opacity),
      );
  }

  void _paintWedge(
    Canvas canvas,
    Offset center,
    double headingDegrees,
    Color color,
    double opacity,
  ) {
    // Compass heading: 0° is up (north), increasing clockwise.
    final angle = (headingDegrees - 90) * math.pi / 180;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final tip = center + direction * _wedgeFar;
    final base = center + direction * _wedgeNear;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        (base + normal * _wedgeHalfWidth).dx,
        (base + normal * _wedgeHalfWidth).dy,
      )
      ..lineTo(
        (base - normal * _wedgeHalfWidth).dx,
        (base - normal * _wedgeHalfWidth).dy,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: _wedgeAlpha * opacity),
    );
  }

  @override
  bool shouldRepaint(_MarkerPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      !identical(oldDelegate.interpolator, interpolator);
}
