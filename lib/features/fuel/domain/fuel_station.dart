import '../../ride/domain/geo_point.dart';

/// A petrol pump from OpenStreetMap (`amenity=fuel`).
class FuelStation {
  const FuelStation({required this.id, required this.point, this.name});

  /// The OpenStreetMap element, as "node/123" or "way/456".
  final String id;
  final GeoPoint point;

  /// Its name or brand, when mapped.
  final String? name;

  /// What to call it on screen.
  String get displayName => name ?? 'Fuel station';

  Map<String, Object?> toJson() => {
    'id': id,
    'lat': point.latitude,
    'lng': point.longitude,
    if (name != null) 'name': name,
  };

  static FuelStation? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final lat = json['lat'];
    final lng = json['lng'];
    final name = json['name'];
    if (id is! String || lat is! num || lng is! num) return null;
    return FuelStation(
      id: id,
      point: GeoPoint(latitude: lat.toDouble(), longitude: lng.toDouble()),
      name: name is String && name.isNotEmpty ? name : null,
    );
  }

  @override
  bool operator ==(Object other) => other is FuelStation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
