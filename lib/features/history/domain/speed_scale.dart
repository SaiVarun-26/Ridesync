import 'dart:math' as math;

/// Maps speeds onto 0 (slowest) to 1 (fastest) for colouring a route.
///
/// The range comes from the ride itself: the 5th to the 95th percentile of
/// the speeds ridden, so one GPS spike or a long stop does not wash out the
/// colours for everything else.
class SpeedScale {
  const SpeedScale({required this.lowMps, required this.highMps});

  /// Speed shown as the coolest colour, in meters per second.
  final double lowMps;

  /// Speed shown as the hottest colour, in meters per second.
  final double highMps;

  /// Narrowest range allowed, so a steady ride shows a mild spread of colour
  /// rather than a harsh one.
  static const double minSpanMps = 2;

  /// Where [speedMps] falls between [lowMps] and [highMps], from 0 to 1.
  double normalize(double speedMps) {
    final span = highMps - lowMps;
    if (span <= 0) return 0.5;
    return ((speedMps - lowMps) / span).clamp(0.0, 1.0);
  }

  /// The scale for a ride whose riders recorded the speed series in [series].
  /// With no usable speeds, a flat scale around 0.
  factory SpeedScale.fromSeries(Iterable<List<double>> series) {
    final speeds = <double>[
      for (final s in series)
        for (final v in s)
          if (v.isFinite) v,
    ]..sort();
    if (speeds.isEmpty) return const SpeedScale(lowMps: 0, highMps: minSpanMps);

    double at(double fraction) =>
        speeds[((speeds.length - 1) * fraction).round()];
    var low = at(0.05);
    var high = at(0.95);
    if (high - low < minSpanMps) {
      final middle = (low + high) / 2;
      low = math.max(0, middle - minSpanMps / 2);
      high = low + minSpanMps;
    }
    return SpeedScale(lowMps: low, highMps: high);
  }

  /// [speeds] averaged with their [radius] neighbours on each side, which
  /// evens out GPS speed noise. The result has the same length.
  static List<double> smooth(List<double> speeds, {required int radius}) {
    if (speeds.isEmpty || radius <= 0) return speeds;
    final result = List<double>.filled(speeds.length, 0);
    for (var i = 0; i < speeds.length; i++) {
      final from = math.max(0, i - radius);
      final to = math.min(speeds.length - 1, i + radius);
      var sum = 0.0;
      for (var j = from; j <= to; j++) {
        sum += speeds[j];
      }
      result[i] = sum / (to - from + 1);
    }
    return result;
  }
}
