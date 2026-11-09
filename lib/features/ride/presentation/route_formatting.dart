/// Human-readable route figures for the planning screen.
abstract final class RouteFormatting {
  static const int _metersPerKm = 1000;
  static const int _wholeKmFrom = 100;
  static const int _secondsPerMinute = 60;
  static const int _minutesPerHour = 60;

  /// "850 m", "42.3 km", or "128 km".
  static String distance(int meters) {
    if (meters < _metersPerKm) return '$meters m';
    final km = meters / _metersPerKm;
    return km >= _wholeKmFrom
        ? '${km.round()} km'
        : '${km.toStringAsFixed(1)} km';
  }

  /// "< 1 min", "45 min", or "1 h 05 min".
  static String duration(int seconds) {
    final totalMinutes = (seconds / _secondsPerMinute).round();
    if (totalMinutes < 1) return '< 1 min';
    final hours = totalMinutes ~/ _minutesPerHour;
    final minutes = totalMinutes % _minutesPerHour;
    if (hours == 0) return '$minutes min';
    return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  }
}
