import 'package:flutter/material.dart';

/// The speed tones of a route, all in the rider's own colour: a deeper tone
/// when slow, the colour itself at pace, and a lifted, lighter tone when
/// fast. One hue per rider, so a route is always recognisably theirs, with
/// enough change in brightness to show where the ride was quick.
///
/// Routes are drawn in short solid segments, each in the tone for its speed,
/// so the ramp reads as smooth while every stroke stays one flat colour.
abstract final class HeatPalette {
  static final Map<(Color, int), List<Color>> _cache = {};

  /// The colour for a position [t] from 0 (slowest) to 1 (fastest) in the
  /// ramp of [base].
  static Color colorAt(Color base, double t) {
    final stops = _stops(base);
    final clamped = t.clamp(0.0, 1.0);
    final scaled = clamped * (stops.length - 1);
    final index = scaled.floor().clamp(0, stops.length - 2);
    return Color.lerp(stops[index], stops[index + 1], scaled - index)!;
  }

  /// [steps] evenly spaced tones of [base], slowest first. Cached per colour,
  /// so callers that group route segments by tone can ask every frame.
  static List<Color> steps(Color base, int steps) {
    return _cache.putIfAbsent((base, steps), () => [
      for (var i = 0; i < steps; i++) colorAt(base, i / (steps - 1)),
    ]);
  }

  static List<Color> _stops(Color base) => [
    Color.lerp(base, Colors.black, 0.35)!,
    Color.lerp(base, Colors.black, 0.15)!,
    base,
    Color.lerp(base, Colors.white, 0.45)!,
  ];
}
