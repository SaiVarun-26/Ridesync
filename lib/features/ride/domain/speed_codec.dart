/// Packs a list of speeds into a short string, one character per speed, so a
/// ride's speeds can be stored beside its encoded route.
///
/// Speeds are kept to half a meter per second (under 2 km/h) and capped at
/// [maxSpeedMps]. Each speed becomes one printable character.
abstract final class SpeedCodec {
  /// The fastest speed that can be stored, in meters per second.
  static const double maxSpeedMps = 45;

  static const int _base = 35; // '#'
  static const double _stepsPerMps = 2;

  static String encode(List<double> speedsMps) {
    final buffer = StringBuffer();
    for (final speed in speedsMps) {
      final clamped = speed.isNaN ? 0.0 : speed.clamp(0.0, maxSpeedMps);
      buffer.writeCharCode(_base + (clamped * _stepsPerMps).round());
    }
    return buffer.toString();
  }

  static List<double> decode(String encoded) {
    return [
      for (final unit in encoded.codeUnits)
        ((unit - _base).clamp(0, (maxSpeedMps * _stepsPerMps).round()) /
                _stepsPerMps)
            .toDouble(),
    ];
  }
}
