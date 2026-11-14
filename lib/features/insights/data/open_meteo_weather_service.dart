import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../ride/domain/geo_point.dart';
import '../domain/weather/weather_repositories.dart';
import '../domain/weather/weather_snapshot.dart';

/// [WeatherService] backed by Open-Meteo (https://open-meteo.com), which needs
/// no API key. Its data is CC BY 4.0, so the app credits it wherever weather
/// is shown.
///
/// One small HTTPS request per ride; any failure (offline, slow, a bad
/// answer) just means the ride has no weather.
class OpenMeteoWeatherService implements WeatherService {
  OpenMeteoWeatherService({
    this.timeout = const Duration(seconds: 8),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration timeout;
  final DateTime Function() _clock;

  static const String _host = 'api.open-meteo.com';
  static const String _path = '/v1/forecast';

  /// Coordinates are sent rounded to about 1 km: plenty for weather, and no
  /// more precise than the request needs to be.
  static double _coarse(double value) => (value * 100).roundToDouble() / 100;

  @override
  Future<WeatherSnapshot?> current(GeoPoint at) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final uri = Uri.https(_host, _path, {
        'latitude': '${_coarse(at.latitude)}',
        'longitude': '${_coarse(at.longitude)}',
        'current':
            'temperature_2m,relative_humidity_2m,weather_code,'
            'wind_speed_10m,is_day',
        'wind_speed_unit': 'kmh',
        'timezone': 'auto',
      });
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return parse(body, capturedAtMs: _clock().millisecondsSinceEpoch);
    } on Object catch (e) {
      debugPrint('Weather request failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// The snapshot in an Open-Meteo `current` response, or `null`.
  @visibleForTesting
  static WeatherSnapshot? parse(String body, {required int capturedAtMs}) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final current = json['current'];
    if (current is! Map) return null;
    final temperature = current['temperature_2m'];
    final code = current['weather_code'];
    if (temperature is! num || code is! num) return null;
    final humidity = current['relative_humidity_2m'];
    final wind = current['wind_speed_10m'];
    final isDay = current['is_day'];
    final snapshot = WeatherSnapshot(
      temperatureC: temperature.toDouble(),
      wmoCode: code.toInt(),
      capturedAtMs: capturedAtMs,
      humidityPercent: humidity is num ? humidity.toDouble() : null,
      windKmh: wind is num ? wind.toDouble() : null,
      isDay: isDay is num ? isDay != 0 : null,
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
}
