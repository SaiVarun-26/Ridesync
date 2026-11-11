import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// The OpenStreetMap tiles in the app's night style, shared by every map.
///
/// Turns the light OSM style into a calm night map: greyscale, inverted, and
/// dimmed, with a faint cool tint. Applied once to the whole tile layer.
class NightTileLayer extends StatelessWidget {
  const NightTileLayer({super.key});

  static const double maxZoom = 19;
  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _userAgentPackage = 'com.ridesync.ridesync';

  static const ColorFilter _nightTiles = ColorFilter.matrix(<double>[
    -0.17, -0.572, -0.058, 0, 214, //
    -0.17, -0.572, -0.058, 0, 216, //
    -0.17, -0.572, -0.058, 0, 222, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: _nightTiles,
      child: TileLayer(
        urlTemplate: _tileUrl,
        userAgentPackageName: _userAgentPackage,
        maxNativeZoom: maxZoom.toInt(),
        // Tiles ease in over the dark map instead of popping into place.
        tileDisplay: const TileDisplay.fadeIn(
          duration: Duration(milliseconds: 240),
        ),
      ),
    );
  }
}
