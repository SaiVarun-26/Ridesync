/// Rider-facing text for ride figures, shared by the notification and the
/// in-app cards so they always read the same.
abstract final class RideFormat {
  static const double _metersPerKm = 1000;
  static const double _wholeKmFrom = 10;
  static const double _kmhPerMps = 3.6;
  static const int _secondsPerMinute = 60;
  static const int _secondsPerHour = 3600;

  /// "850 m", "4.2 km", or "67 km".
  static String distance(double meters) {
    if (meters < _metersPerKm) return '${meters.round()} m';
    final km = meters / _metersPerKm;
    return km >= _wholeKmFrom
        ? '${km.round()} km'
        : '${km.toStringAsFixed(1)} km';
  }

  /// "38 km/h".
  static String speed(double metersPerSecond) =>
      '${(metersPerSecond * _kmhPerMps).round()} km/h';

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "7 Nov 2026".
  static String date(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  /// "6:42 PM".
  static String time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  /// "+0:05" style gap behind the first finisher.
  static String gap(Duration value) => '+${duration(value)}';

  /// "12:04", or "1:12:04" once past an hour.
  static String duration(Duration value) {
    final total = value.inSeconds;
    final hours = total ~/ _secondsPerHour;
    final minutes = (total % _secondsPerHour) ~/ _secondsPerMinute;
    final seconds = total % _secondsPerMinute;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }
}
