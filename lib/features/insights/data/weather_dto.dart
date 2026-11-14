import '../domain/weather/weather_snapshot.dart';

/// Where ride weather lives in the Realtime Database, and its field names.
abstract final class RideWeatherPaths {
  static String weather(String code) => 'rideWeather/$code';

  static const String temperatureC = 'temperatureC';
  static const String code = 'code';
  static const String humidity = 'humidity';
  static const String windKmh = 'windKmh';
  static const String isDay = 'isDay';
  static const String capturedAt = 'capturedAt';
}

/// Converts [WeatherSnapshot] to and from its stored form.
abstract final class WeatherDto {
  static Map<String, Object?> toValue(WeatherSnapshot s) => {
    RideWeatherPaths.temperatureC: _round(s.temperatureC),
    RideWeatherPaths.code: s.wmoCode,
    if (s.humidityPercent != null)
      RideWeatherPaths.humidity: _round(s.humidityPercent!),
    if (s.windKmh != null) RideWeatherPaths.windKmh: _round(s.windKmh!),
    if (s.isDay != null) RideWeatherPaths.isDay: s.isDay,
    RideWeatherPaths.capturedAt: s.capturedAtMs,
  };

  /// The snapshot in [value], or `null` if it is missing or not plausible.
  static WeatherSnapshot? fromValue(Object? value) {
    if (value is! Map) return null;
    final temperature = value[RideWeatherPaths.temperatureC];
    final code = value[RideWeatherPaths.code];
    final captured = value[RideWeatherPaths.capturedAt];
    if (temperature is! num || code is! num || captured is! num) return null;
    final humidity = value[RideWeatherPaths.humidity];
    final wind = value[RideWeatherPaths.windKmh];
    final isDay = value[RideWeatherPaths.isDay];
    final snapshot = WeatherSnapshot(
      temperatureC: temperature.toDouble(),
      wmoCode: code.toInt(),
      capturedAtMs: captured.toInt(),
      humidityPercent: humidity is num ? humidity.toDouble() : null,
      windKmh: wind is num ? wind.toDouble() : null,
      isDay: isDay is bool ? isDay : null,
    );
    return WeatherSnapshot.isPlausible(
          temperatureC: snapshot.temperatureC,
          wmoCode: snapshot.wmoCode,
          humidityPercent: snapshot.humidityPercent,
          windKmh: snapshot.windKmh,
        )
        ? snapshot
        : null;
  }

  static double _round(double value) => (value * 10).roundToDouble() / 10;
}
