import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../history/presentation/route/route_markers.dart';
import '../../../ride/domain/geo_point.dart';
import '../../../ride/presentation/map/night_tile_layer.dart';

/// The ride on the share card: the real map, in the app's night style, with
/// the route drawn over it in the rider's colour and its start and finish
/// marked, so the card says where the ride happened.
///
/// A still picture: nothing on it moves or responds to touch, so what the
/// preview shows is exactly what the shared image holds.
class ShareRouteMap extends StatelessWidget {
  const ShareRouteMap({
    super.key,
    required this.points,
    required this.color,
    required this.size,
  });

  final List<GeoPoint> points;
  final Color color;
  final Size size;

  static const double _lineWidth = 4.5;
  static const double _casingWidth = 8;

  @override
  Widget build(BuildContext context) {
    final line = [for (final p in points) LatLng(p.latitude, p.longitude)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: _fit(line),
                    backgroundColor: AppColors.background,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    const NightTileLayer(),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: line,
                          strokeWidth: _lineWidth,
                          color: color,
                          borderStrokeWidth: (_casingWidth - _lineWidth) / 2,
                          borderColor: Colors.black.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: line.first,
                          child: StartMarker(color: color),
                        ),
                        Marker(
                          point: line.last,
                          width: FinishFlagMarker.width,
                          height: FinishFlagMarker.height,
                          alignment: Alignment.topCenter,
                          child: const FinishFlagMarker(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // The map data's credit, which travels with the image.
              Positioned(
                right: AppSpacing.sm,
                bottom: AppSpacing.xs,
                child: Text(
                  '© OpenStreetMap',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Frames the whole route, with room for the markers.
  static CameraFit _fit(List<LatLng> line) {
    var south = double.infinity;
    var north = -double.infinity;
    var west = double.infinity;
    var east = -double.infinity;
    for (final p in line) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    const minSpan = 0.0008;
    if (north - south < minSpan) {
      final m = (north + south) / 2;
      south = m - minSpan / 2;
      north = m + minSpan / 2;
    }
    if (east - west < minSpan) {
      final m = (east + west) / 2;
      west = m - minSpan / 2;
      east = m + minSpan / 2;
    }
    return CameraFit.bounds(
      bounds: LatLngBounds(LatLng(south, west), LatLng(north, east)),
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      maxZoom: 17,
    );
  }
}
