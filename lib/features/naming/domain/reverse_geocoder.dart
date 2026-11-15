import '../../ride/domain/geo_point.dart';
import 'place_address.dart';

/// Contract for turning a position into the area it lies in.
///
/// Implementations never throw: a place that cannot be found, or a service
/// that cannot be reached, gives `null`.
abstract interface class ReverseGeocoder {
  Future<PlaceAddress?> lookup(GeoPoint at);
}
