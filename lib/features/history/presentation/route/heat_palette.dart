import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The speed colours of a route, all in the RideSync purple: a quiet, greyed
/// purple when slow, the brand purple at pace, and a bright lifted purple when
/// fast. One hue, so a route reads as part of the app rather than a rainbow,
/// with enough change in brightness to show where the ride was quick.
///
/// Routes are drawn in short solid segments, each in the colour for its speed,
/// so the ramp reads as smooth while every stroke stays one flat colour.
abstract final class HeatPalette {
  /// The brightest, fastest tone: the brand purple lifted toward white.
  static final Color fastest = Color.lerp(
    AppColors.primary,
    Colors.white,
    0.45,
  )!;

  /// The slowest tone: the brand purple faded toward grey, still clear on the
  /// night map.
  static final Color slowest = Color.lerp(
    AppColors.primary,
    AppColors.textSecondary,
    0.7,
  )!;

  static final List<Color> _stops = [
    slowest,
    Color.lerp(AppColors.primary, AppColors.textSecondary, 0.35)!,
    AppColors.primary,
    fastest,
  ];

  /// The colour for a position [t] from 0 (slowest) to 1 (fastest).
  static Color colorAt(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final scaled = clamped * (_stops.length - 1);
    final index = scaled.floor().clamp(0, _stops.length - 2);
    return Color.lerp(_stops[index], _stops[index + 1], scaled - index)!;
  }

  /// [steps] evenly spaced colours, slowest first. Computed once by callers
  /// that group route segments by colour.
  static List<Color> steps(int steps) => [
    for (var i = 0; i < steps; i++) colorAt(i / (steps - 1)),
  ];
}
