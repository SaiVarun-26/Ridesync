import '../../ride/domain/geo_point.dart';

/// A petrol pump from OpenStreetMap (`amenity=fuel`).
class FuelStation {
  const FuelStation({
    required this.id,
    required this.point,
    this.name,
    this.brand,
    this.operator,
  });

  /// The OpenStreetMap element, as "node/123" or "way/456".
  final String id;
  final GeoPoint point;

  /// Its name (or, when unnamed, its brand), when mapped.
  final String? name;

  /// The OpenStreetMap `brand` and `operator` tags, when mapped; used to tell
  /// which company runs it.
  final String? brand;
  final String? operator;

  /// What to call it on screen.
  String get displayName => name ?? 'Fuel station';

  /// This station with the brand details of [other] filled in where missing.
  FuelStation withDetailsFrom(FuelStation other) => FuelStation(
    id: id,
    point: point,
    name: name ?? other.name,
    brand: brand ?? other.brand,
    operator: operator ?? other.operator,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'lat': point.latitude,
    'lng': point.longitude,
    if (name != null) 'name': name,
    if (brand != null) 'brand': brand,
    if (operator != null) 'operator': operator,
  };

  static FuelStation? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final lat = json['lat'];
    final lng = json['lng'];
    if (id is! String || lat is! num || lng is! num) return null;
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    return FuelStation(
      id: id,
      point: GeoPoint(latitude: lat.toDouble(), longitude: lng.toDouble()),
      name: text(json['name']),
      brand: text(json['brand']),
      operator: text(json['operator']),
    );
  }

  @override
  bool operator ==(Object other) => other is FuelStation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
