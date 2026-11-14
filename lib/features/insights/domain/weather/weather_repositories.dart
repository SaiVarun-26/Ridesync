import 'dart:async';
import 'dart:developer' as developer;

import '../../../ride/domain/geo_point.dart';
import 'weather_snapshot.dart';

/// Current conditions from a weather service.
abstract interface class WeatherService {
  /// The weather at [at] right now, or `null` when it cannot be had (no
  /// network, the service is down, or its answer made no sense). Never throws.
  Future<WeatherSnapshot?> current(GeoPoint at);
}

/// Where each ride's weather snapshot is kept.
abstract interface class RideWeatherRepository {
  /// The snapshot stored for ride [code], or `null` if it has none. Falls back
  /// to the device's copy when offline. Never throws.
  Future<WeatherSnapshot?> load(String code);

  /// Whether ride [code] already has a snapshot. `true` when unsure, so a
  /// failed check never causes an extra request to the weather service.
  Future<bool> exists(String code);

  /// Stores [snapshot] for ride [code] unless it already has one. Returns
  /// whether it was stored. Never throws.
  Future<bool> saveOnce(String code, WeatherSnapshot snapshot);
}

/// Takes one weather snapshot per ride, at its start.
///
/// Whichever rider gets a GPS fix first records it; everyone else finds it
/// already there and does nothing. The database also only accepts the first
/// write, so two riders racing cannot overwrite each other. It runs in the
/// background and never affects the ride if it fails.
class RideWeatherRecorder {
  RideWeatherRecorder({
    required WeatherService service,
    required RideWeatherRepository repository,
  }) : _service = service,
       _repository = repository;

  final WeatherService _service;
  final RideWeatherRepository _repository;

  /// Rides already handled on this device, so a reopened map does not ask
  /// again.
  final Set<String> _handled = {};

  /// Records the weather at [at] for ride [code], once.
  Future<void> captureOnce({required String code, required GeoPoint at}) async {
    if (!_handled.add(code)) return;
    try {
      if (await _repository.exists(code)) return;
      final snapshot = await _service.current(at);
      if (snapshot == null) {
        // Let a later map open try again.
        _handled.remove(code);
        return;
      }
      await _repository.saveOnce(code, snapshot);
    } on Object catch (e) {
      _handled.remove(code);
      developer.log('Weather snapshot skipped: $e', name: 'RideSync');
    }
  }
}
