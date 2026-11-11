import 'package:flutter/painting.dart';

import '../../../../core/theme/app_colors.dart';

/// The speed colours: blue (slow) through green, yellow and orange to red
/// (fast), blended smoothly in between.
abstract final class HeatPalette {
  static const List<Color> _stops = [
    AppColors.route, // blue
    AppColors.neonGreen,
    AppColors.yellow,
    AppColors.orange,
    Color(0xFFFF3B3B), // red
  ];

  /// The colour for a position [t] from 0 (slowest) to 1 (fastest).
  static Color colorAt(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final scaled = clamped * (_stops.length - 1);
    final index = scaled.floor().clamp(0, _stops.length - 2);
    return Color.lerp(_stops[index], _stops[index + 1], scaled - index)!;
  }

  /// The colours of a legend bar, slowest first.
  static List<Color> get gradient => _stops;

  /// [steps] evenly spaced colours, slowest first. Computed once by callers
  /// that group route segments by colour.
  static List<Color> steps(int steps) => [
    for (var i = 0; i < steps; i++) colorAt(i / (steps - 1)),
  ];
}
