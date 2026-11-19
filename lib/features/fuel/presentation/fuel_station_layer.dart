import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/theme/app_colors.dart';
import '../domain/fuel_brand.dart';
import '../domain/fuel_station.dart';

/// One mark on the map: a single station, or several close together.
class FuelMark {
  FuelMark(this.stations, this.point);

  final List<FuelStation> stations;

  /// Where it is drawn: the station, or the middle of the group.
  final LatLng point;

  bool get isCluster => stations.length > 1;

  /// The company every station in the group belongs to, if they all share
  /// one; a mixed group is drawn as generic fuel.
  FuelBrand? get sharedBrand {
    final first = FuelBrands.of(stations.first);
    if (first == null) return null;
    for (final s in stations.skip(1)) {
      if (!identical(FuelBrands.of(s), first)) return null;
    }
    return first;
  }
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

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = FuelStationLayer.opacityAt(camera.zoom);
    // A little smaller far out, as well as fainter.
    final scale = 0.85 + 0.15 * ((opacity - 0.45) / 0.55);
    final bounds = Offset.zero & size;
    for (final mark in FuelClusters.of(camera, stations)) {
      final at = camera.latLngToScreenOffset(mark.point);
      if (!bounds.inflate(24).contains(at)) continue;
      final n = mark.stations.length;
      FuelMarkerArt.paint(
        canvas,
        at,
        brand: mark.isCluster ? mark.sharedBrand : FuelBrands.of(mark.stations.single),
        count: mark.isCluster ? n : null,
        scale: scale,
        opacity: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(_FuelPainter old) =>
      old.camera != camera || !identical(old.stations, stations);
}

/// How a fuel station is drawn, everywhere it appears: a flat disc in the
/// company's colour with its short label in bold, or the orange disc with a
/// white pump for unknown companies. A white ring and a dark hairline keep
/// it clear on dark, light and satellite maps alike; labels carry a dark
/// outline so white text stays readable on light colours and in sunlight.
abstract final class FuelMarkerArt {
  static const double radius = 10;
  static const double clusterRadius = 11.5;
  static const double ring = 1.8;

  /// Paints one marker centred on [at]: [brand]'s (or the generic one), or a
  /// group of [count] when given.
  static void paint(
    Canvas canvas,
    Offset at, {
    required FuelBrand? brand,
    int? count,
    double scale = 1,
    double opacity = 1,
  }) {
    final r = (count == null ? radius : clusterRadius) * scale;
    final fill = brand?.color ?? FuelStationLayer.color;
    canvas
      ..drawCircle(
        at,
        r + ring + 1,
        Paint()..color = Colors.black.withValues(alpha: 0.55 * opacity),
      )
      ..drawCircle(
        at,
        r + ring,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      )
      ..drawCircle(at, r, Paint()..color = fill.withValues(alpha: opacity));

    final String? text = count != null
        ? (count > 99 ? '99+' : '$count')
        : brand?.label;
    final glyphs = _glyphs(text, brand?.labelColor ?? Colors.white, opacity);
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(scale);
    for (final g in glyphs) {
      g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
    }
    canvas.restore();
  }

  /// Laid-out label (outline, then fill) by text, colour and opacity step,
  /// so painting a frame lays out no text.
  static final Map<(String, int, int), List<TextPainter>> _cache = {};

  static List<TextPainter> _glyphs(String? text, Color color, double opacity) {
    final step = (opacity * 20).round();
    final key = (text ?? '', color.toARGB32(), step);
    return _cache[key] ??= () {
      const icon = Icons.local_gas_station_rounded;
      TextStyle style(Paint? stroke, Color? fill) => text == null
          ? TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: 12.5,
              foreground: stroke,
              color: fill,
            )
          : TextStyle(
              fontSize: text.length >= 3
                  ? 8
                  : text.length == 2
                  ? 9.5
                  : 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: text.length >= 2 ? -0.3 : 0,
              height: 1,
              foreground: stroke,
              color: fill,
            );
      TextPainter layout(TextStyle s) => TextPainter(
        text: TextSpan(
          text: text ?? String.fromCharCode(icon.codePoint),
          style: s,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final alpha = step / 20;
      return [
        layout(
          style(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black.withValues(alpha: 0.45 * alpha),
            null,
          ),
        ),
        layout(style(null, color.withValues(alpha: alpha))),
      ];
    }();
  }
}

/// A fuel station's marker as a widget, for places outside the map (the
/// station sheet), drawn exactly as on the map.
class FuelBrandBadge extends StatelessWidget {
  const FuelBrandBadge({super.key, required this.station, this.size = 40});

  final FuelStation station;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = FuelBrands.of(station);
    return Semantics(
      label: brand?.name ?? 'Fuel station',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BadgePainter(brand)),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter(this.brand);

  final FuelBrand? brand;

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        size.shortestSide /
        2 /
        (FuelMarkerArt.radius + FuelMarkerArt.ring + 1);
    FuelMarkerArt.paint(
      canvas,
      size.center(Offset.zero),
      brand: brand,
      scale: scale,
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.brand != brand;
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
