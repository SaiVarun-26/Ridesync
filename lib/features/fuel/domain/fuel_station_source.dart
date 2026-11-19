import '../../ride/domain/geo_point.dart';
import 'fuel_station.dart';

/// The services fuel stations are looked up in. Both read OpenStreetMap data
/// but index it separately, so each can hold stations the other lacks; their
/// answers are merged.
abstract interface class FuelStationProviders {
  /// The nearest stations to [center] within [radiusMeters], at most a
  /// service-set number of them ([FuelProviderFound.capped] when that limit
  /// was hit before the radius was covered).
  Future<FuelProviderResult> nearest(GeoPoint center, double radiusMeters);

  /// Every station in the box, with no cap.
  Future<FuelProviderResult> inBox({
    required double south,
    required double west,
    required double north,
    required double east,
  });
}

/// What one provider answered.
sealed class FuelProviderResult {
  const FuelProviderResult({required this.provider, required this.elapsed});

  /// Which service answered (for the log).
  final String provider;
  final Duration elapsed;
}

final class FuelProviderFound extends FuelProviderResult {
  const FuelProviderFound(
    this.stations, {
    required this.capped,
    required super.provider,
    required super.elapsed,
  });

  final List<FuelStation> stations;

  /// Whether the service's result limit was reached before the whole radius
  /// was covered: there may be more, further out.
  final bool capped;
}

final class FuelProviderFailed extends FuelProviderResult {
  const FuelProviderFailed(
    this.reason, {
    this.throttled = false,
    required super.provider,
    required super.elapsed,
  });

  final String reason;

  /// The service asked to slow down (HTTP 429).
  final bool throttled;
}
