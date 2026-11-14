import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../history/data/json_cache.dart';
import '../domain/weather/weather_repositories.dart';
import '../domain/weather/weather_snapshot.dart';
import 'weather_dto.dart';

/// [RideWeatherRepository] on the Realtime Database, at `rideWeather/{code}`,
/// with a copy kept on the device so a ride's weather shows offline too.
///
/// The database rules accept the first snapshot for a ride and refuse any
/// later write, so a ride's weather is fixed once taken.
class RtdbRideWeatherRepository implements RideWeatherRepository {
  RtdbRideWeatherRepository({
    required FirebaseDatabase database,
    required JsonCache cache,
    this.timeout = const Duration(seconds: 8),
  }) : _database = database,
       _cache = cache;

  final FirebaseDatabase _database;
  final JsonCache _cache;
  final Duration timeout;

  static String _cacheKey(String code) => 'weather_$code';

  @override
  Future<WeatherSnapshot?> load(String code) async {
    try {
      final snapshot = await _database
          .ref(RideWeatherPaths.weather(code))
          .get()
          .timeout(timeout);
      final weather = WeatherDto.fromValue(snapshot.value);
      if (weather != null) {
        await _cache.write(_cacheKey(code), WeatherDto.toValue(weather));
      }
      return weather;
    } on Object catch (e) {
      debugPrint('Loading ride weather failed: $e');
      return WeatherDto.fromValue(await _cache.read(_cacheKey(code)));
    }
  }

  @override
  Future<bool> exists(String code) async {
    try {
      final snapshot = await _database
          .ref(RideWeatherPaths.weather(code))
          .get()
          .timeout(timeout);
      return snapshot.exists;
    } on Object {
      return true;
    }
  }

  @override
  Future<bool> saveOnce(String code, WeatherSnapshot snapshot) async {
    try {
      await _database
          .ref(RideWeatherPaths.weather(code))
          .set(WeatherDto.toValue(snapshot))
          .timeout(timeout);
      return true;
    } on Object catch (e) {
      // Usually another rider got there first, which the rules enforce.
      debugPrint('Saving ride weather skipped: $e');
      return false;
    }
  }
}
