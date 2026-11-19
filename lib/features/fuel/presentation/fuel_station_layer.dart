import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/theme/app_colors.dart';
import '../domain/fuel_station.dart';

/// One mark on the map: a single station, or several close together.
class FuelMark {
  FuelMark(this.stations, this.point);

  final List<FuelStation> stations;

  /// Where it is drawn: the station, or the middle of the group.
  final LatLng point;

  bool get isCluster => stations.length > 1;
}

/// Groups stations that would sit on top of each other at the camera's zoom.
///
/// Stations are binned on a grid fixed to the world at the current whole
/// zoom level, so groups hold still while the map pans or turns and only
/// split or merge as the zoom crosses a level. From [clusterBelowZoom] in,
/// every station stands alone.
abstract final class FuelClusters {
  static const double clusterBelowZoom = 15;

  /// Grid size, in pixels at the binning zoom.
  static const double _binPixels = 56;

  static List<FuelMark> of(MapCamera camera, List<FuelStation> stations) {
    LatLng at(FuelStation s) => LatLng(s.point.latitude, s.point.longitude);
    if (camera.zoom >= clusterBelowZoom) {
      return [for (final s in stations) FuelMark([s], at(s))];
    }
    final zoom = camera.zoom.floorToDouble();
    final bins = <(int, int), List<FuelStation>>{};
    for (final s in stations) {
      final p = camera.projectAtZoom(at(s), zoom);
      final key = ((p.dx / _binPixels).floor(), (p.dy / _binPixels).floor());
      (bins[key] ??= []).add(s);
    }
    return [
      for (final group in bins.values)
        FuelMark(
          group,
          LatLng(
            group.map((s) => s.point.latitude).reduce((a, b) => a + b) /
                group.length,
            group.map((s) => s.point.longitude).reduce((a, b) => a + b) /
                group.length,
          ),
        ),
    ];
  }

  /// The mark under [screen], if any.
  static FuelMark? hit(
    MapCamera camera,
    List<FuelStation> stations,
    Offset screen, {
    double radius = 24,
  }) {
    FuelMark? best;
    var bestDistance = radius;
    for (final mark in of(camera, stations)) {
      final d = (camera.latLngToScreenOffset(mark.point) - screen).distance;
      if (d <= bestDistance) {
        bestDistance = d;
        best = mark;
      }
    }
    return best;
  }
}

/// Fuel stations on the live map: small orange discs with a white pump,
/// grouped into a numbered disc where they crowd together.
///
/// Drawn under the trails and riders, a touch smaller than a rider's
/// marker, and fainter when zoomed out, so they are easy to spot without
/// ever competing with the group. Upright however the map is turned. One
/// painter, no widgets per station.
class FuelStationLayer extends StatelessWidget {
  const FuelStationLayer({super.key, required this.stations});

  final List<FuelStation> stations;

  /// The orange used for fuel, and only for fuel.
  static const Color color = AppColors.orange;

  /// How strongly the marks show at [zoom]: faint far out, full close in.
  static double opacityAt(double zoom) =>
      (0.45 + (zoom - 12) * 0.275).clamp(0.45, 1.0);

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _FuelPainter(camera: camera, stations: stations),
        ),
      ),
    );
  }
}

class _FuelPainter extends CustomPainter {
  _FuelPainter({required this.camera, required this.stations});

  final MapCamera camera;
  final List<FuelStation> stations;

  static const double _radius = 8.5;
  static const double _clusterRadius = 11;
  static const double _ring = 1.6;

  /// Laid-out glyphs, by text and opacity step, so painting a frame lays out
  /// no text.
  static final Map<(String, int), TextPainter> _glyphs = {};

  static TextPainter _glyph(String? label, double opacity) {
    final step = (opacity * 20).round();
    final key = (label ?? '', step);
    final white = Colors.white.withValues(alpha: step / 20);
    const icon = Icons.local_gas_station_rounded;
    return _glyphs[key] ??= TextPainter(
      text: label == null
          ? TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                fontSize: 11,
                color: white,
              ),
            )
          : TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: white,
                height: 1,
              ),
            ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = FuelStationLayer.opacityAt(camera.zoom);
    // A little smaller far out, as well as fainter.
    final scale = 0.85 + 0.15 * ((opacity - 0.45) / 0.55);
    final fill = Paint()
      ..color = FuelStationLayer.color.withValues(alpha: 0.92 * opacity);
    final ring = Paint()
      ..color = AppColors.background.withValues(alpha: 0.85 * opacity);
    final bounds = Offset.zero & size;
    for (final mark in FuelClusters.of(camera, stations)) {
      final at = camera.latLngToScreenOffset(mark.point);
      if (!bounds.inflate(24).contains(at)) continue;
      final r = (mark.isCluster ? _clusterRadius : _radius) * scale;
      canvas
        ..drawCircle(at, r + _ring, ring)
        ..drawCircle(at, r, fill);
      final n = mark.stations.length;
      final glyph = _glyph(
        mark.isCluster ? (n > 99 ? '99+' : '$n') : null,
        opacity,
      );
      final s = mark.isCluster ? 1.0 : scale;
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..scale(s);
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FuelPainter old) =>
      old.camera != camera || !identical(old.stations, stations);
}

/// Distance and time helpers for the station sheet.
abstract final class FuelEstimates {
  /// Roads are rarely straight: a typical detour over the straight line.
  static const double roadFactor = 1.3;

  /// The speed a ride time is estimated at when the rider is not moving
  /// faster: steady town riding.
  static const double typicalSpeedMps = 30 / 3.6;

  /// The road distance to a station [straightMeters] away, roughly.
  static double roadMeters(double straightMeters) =>
      straightMeters * roadFactor;

  /// About how long riding there takes, at [speedMps] or a typical pace.
  static Duration ridingTime(double straightMeters, {double? speedMps}) {
    final speed = math.max(speedMps ?? 0, typicalSpeedMps);
    return Duration(seconds: (roadMeters(straightMeters) / speed).round());
  }
}
