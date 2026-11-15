/// The administrative parts of a place, as a reverse geocoder reports them
/// (`neighbourhood`, `suburb`, `city`…). Streets and house numbers are never
/// kept: a ride is named after an area, not an address.
class PlaceAddress {
  const PlaceAddress(this.parts);

  /// Part name to value, e.g. `suburb: Guindy`.
  final Map<String, String> parts;

  bool get isEmpty => parts.isEmpty;
}
