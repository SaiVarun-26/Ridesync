/// The sky at a moment, grouped from the WMO weather codes weather services
/// report.
enum WeatherCondition {
  clear('Clear'),
  partlyCloudy('Partly cloudy'),
  cloudy('Cloudy'),
  fog('Fog'),
  drizzle('Drizzle'),
  rain('Rain'),
  showers('Showers'),
  snow('Snow'),
  thunderstorm('Thunderstorm');

  const WeatherCondition(this.label);

  final String label;

  /// The condition for WMO weather code [code] (0–99). Unknown codes read as
  /// cloudy rather than failing.
  static WeatherCondition fromWmo(int code) => switch (code) {
    0 => clear,
    1 || 2 => partlyCloudy,
    3 => cloudy,
    45 || 48 => fog,
    >= 51 && <= 57 => drizzle,
    >= 61 && <= 67 => rain,
    >= 71 && <= 77 => snow,
    >= 80 && <= 82 => showers,
    85 || 86 => snow,
    >= 95 && <= 99 => thunderstorm,
    _ => cloudy,
  };

  /// Whether this condition is wet enough to mention in a recap.
  bool get isWet =>
      this == drizzle ||
      this == rain ||
      this == showers ||
      this == snow ||
      this == thunderstorm;
}

/// The weather where and when a ride started, kept with the ride so its
/// history always has the conditions it was ridden in.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.wmoCode,
    required this.capturedAtMs,
    this.humidityPercent,
    this.windKmh,
    this.isDay,
  });

  final double temperatureC;

  /// The WMO weather code (0–99) reported for the start of the ride.
  final int wmoCode;

  /// When the snapshot was taken (epoch millis).
  final int capturedAtMs;

  final double? humidityPercent;
  final double? windKmh;

  /// Whether it was daytime at the start, when the service said so.
  final bool? isDay;

  WeatherCondition get condition => WeatherCondition.fromWmo(wmoCode);

  /// "29°".
  String get temperatureLabel => '${temperatureC.round()}°';

  /// "29° · Partly cloudy".
  String get summary => '$temperatureLabel · ${condition.label}';

  /// Plausible ranges; anything outside them is treated as bad data.
  static bool isPlausible({
    required double temperatureC,
    required int wmoCode,
    double? humidityPercent,
    double? windKmh,
  }) =>
      temperatureC >= -90 &&
      temperatureC <= 70 &&
      wmoCode >= 0 &&
      wmoCode <= 99 &&
      (humidityPercent == null ||
          (humidityPercent >= 0 && humidityPercent <= 100)) &&
      (windKmh == null || (windKmh >= 0 && windKmh <= 500));
}
