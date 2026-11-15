import 'place_address.dart';

/// Names that stand in for a ride's name until it is given one, and the name
/// used when none can be worked out.
abstract final class RideNames {
  /// A group ride's name before the host names it after the ride.
  static const String groupPlaceholder = 'Group Ride';

  /// A solo ride's name before it is named after the ride.
  static const String soloPlaceholder = 'Solo Ride';

  /// Suggested when the end of the ride cannot be placed.
  static const String fallback = 'Free Roam Ride';

  /// Longest ride name accepted.
  static const int maxLength = 40;

  const RideNames._();
}

/// Works out a friendly title for a ride from where it ended. Pure.
///
/// The title names an *area*, in this order of preference: neighbourhood,
/// suburb, locality, town, city. Streets and house numbers are never used, so
/// a ride is never called "Ride to No.12 Street XYZ".
abstract final class RideTitleGenerator {
  /// Address parts to name a ride after, best first. `county` is where
  /// OpenStreetMap keeps the taluk in India (Guindy, Velachery), which reads
  /// better than a city-wide name.
  static const List<String> areaOrder = [
    'neighbourhood',
    'suburb',
    'quarter',
    'city_district',
    'locality',
    'county',
  ];

  /// Used only when none of [areaOrder] gives a name.
  static const List<String> wideOrder = [
    'hamlet',
    'village',
    'town',
    'city',
    'municipality',
  ];

  /// Administrative units ("Zone 8 Anna Nagar", "Ward 174"): the place name
  /// after the number, if any, is kept but ranks below real area names.
  static final RegExp _adminPrefix = RegExp(
    r'^(zone|ward|division|circle|region)\s*(no\.?\s*)?\d+\s*[-,:]?\s*',
    caseSensitive: false,
  );

  /// Names of a block or plot within an area, never a place to ride to.
  static final RegExp _subArea = RegExp(
    r'\b(block|sector|phase|plot|stage|layout)\b',
    caseSensitive: false,
  );

  /// A ride ending this close to where it began went around an area.
  static const double loopMeters = 600;

  /// A ride ending this far from where it began went to somewhere.
  static const double journeyMeters = 3000;

  /// The area [address] puts the place in, or `null` when it names none that
  /// is fit to use.
  static String? areaOf(PlaceAddress? address) {
    if (address == null) return null;
    String? part(String key) => address.parts[key]?.trim();

    // Real area names first, in order.
    for (final key in areaOrder) {
      final value = part(key);
      if (value != null && !_adminPrefix.hasMatch(value) && _isFit(value)) {
        return value;
      }
    }
    // Then the place inside an administrative unit's name.
    for (final key in areaOrder) {
      final value = part(key);
      if (value == null || !_adminPrefix.hasMatch(value)) continue;
      final inner = value.replaceFirst(_adminPrefix, '').trim();
      if (_isFit(inner)) return inner;
    }
    // Last, the town or city.
    for (final key in wideOrder) {
      final value = part(key);
      if (value != null && _isFit(value)) return value;
    }
    return null;
  }

  /// The suggested title.
  ///
  /// [startToEndMeters] is the straight-line distance from the start to the
  /// end of the ride, when known: a loop is "around" its area, a long trip is
  /// "to" it, and anything between is "near" it.
  static String suggest({
    required PlaceAddress? address,
    double? startToEndMeters,
  }) {
    final area = areaOf(address);
    if (area == null) return RideNames.fallback;
    final distance = startToEndMeters;
    final phrase = distance == null
        ? 'near'
        : distance <= loopMeters
        ? 'around'
        : distance >= journeyMeters
        ? 'to'
        : 'near';
    return clip('Ride $phrase $area');
  }

  /// [name] cut to the longest allowed length at a word boundary.
  static String clip(String name) {
    if (name.length <= RideNames.maxLength) return name;
    final cut = name.substring(0, RideNames.maxLength);
    final space = cut.lastIndexOf(' ');
    return (space > 8 ? cut.substring(0, space) : cut).trim();
  }

  /// Whether [value] reads as an area name rather than an address: it must
  /// not start with a digit or carry address markers.
  static bool _isFit(String value) {
    if (value.length < 2 || value.length > 32) return false;
    // Any number marks an address or a numbered unit, not an area name.
    if (RegExp(r'\d').hasMatch(value)) return false;
    if (_subArea.hasMatch(value)) return false;
    final lower = value.toLowerCase();
    return !(lower.contains('no.') ||
        lower.contains('#') ||
        lower.contains('plot ') ||
        lower.contains('door ') ||
        RegExp(r'\d{3,}').hasMatch(value));
  }
}
