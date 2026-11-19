import 'dart:ui' show Color;

import 'fuel_station.dart';

/// A fuel company as RideSync draws it: a disc in its signature colour with
/// a short bold label. No company logos are used.
///
/// Adding a company means adding one entry to [FuelBrands.all]; detection
/// and drawing read only from there.
class FuelBrand {
  const FuelBrand({
    required this.id,
    required this.name,
    required this.label,
    required this.color,
    required this.aliases,
    this.labelColor = const Color(0xFFFFFFFF),
  });

  /// A stable id: "shell", "hp".
  final String id;

  /// What it is called on screen: "Indian Oil".
  final String name;

  /// The text on the marker: "IO".
  final String label;
  final Color color;
  final Color labelColor;

  /// Ways the company is written in OpenStreetMap, lower case. Each is
  /// matched as whole words, so "hp" matches "HP Petrol Pump" but not
  /// "Shop".
  final List<String> aliases;
}

/// Every known fuel company, and how a station's company is found.
abstract final class FuelBrands {
  /// Checked in this order: put more specific names ("jio bp") before the
  /// shorter ones they contain ("bp").
  static const List<FuelBrand> all = [
    FuelBrand(
      id: 'reliance',
      name: 'Reliance',
      label: 'R',
      color: Color(0xFF0B2A6B),
      aliases: ['reliance', 'jio bp', 'jiobp', 'jio'],
    ),
    FuelBrand(
      id: 'shell',
      name: 'Shell',
      label: 'S',
      color: Color(0xFFF2B705),
      aliases: ['shell'],
    ),
    FuelBrand(
      id: 'hp',
      name: 'Hindustan Petroleum',
      label: 'HP',
      color: Color(0xFF1565C0),
      aliases: [
        'hp',
        'hpcl',
        'hindustan petroleum',
        'hindusthan petroleum',
        'hp petrol',
      ],
    ),
    FuelBrand(
      id: 'bharat_petroleum',
      name: 'Bharat Petroleum',
      label: 'BP',
      color: Color(0xFF0D47A1),
      aliases: ['bpcl', 'bharat petroleum', 'bharat petrol', 'bp'],
    ),
    FuelBrand(
      id: 'indian_oil',
      name: 'Indian Oil',
      label: 'IO',
      color: Color(0xFFE8590C),
      aliases: ['iocl', 'ioc', 'indian oil', 'indianoil', 'indian oil corp'],
    ),
    FuelBrand(
      id: 'nayara',
      name: 'Nayara',
      label: 'N',
      color: Color(0xFF1B8A3A),
      aliases: ['nayara'],
    ),
    FuelBrand(
      id: 'essar',
      name: 'Essar',
      label: 'E',
      color: Color(0xFFD32F2F),
      aliases: ['essar'],
    ),
  ];

  /// Remembered per station, so a map frame never matches text.
  static final Expando<Object> _memo = Expando('fuel brand');
  static const Object _none = Object();

  /// [station]'s company, from its `brand`, then `operator`, then `name`;
  /// `null` when none is recognised.
  static FuelBrand? of(FuelStation station) {
    final memo = _memo[station];
    if (memo != null) return identical(memo, _none) ? null : memo as FuelBrand;
    FuelBrand? found;
    for (final field in [station.brand, station.operator, station.name]) {
      found = match(field);
      if (found != null) break;
    }
    _memo[station] = found ?? _none;
    return found;
  }

  /// The company [text] names, if any.
  static FuelBrand? match(String? text) {
    if (text == null) return null;
    final words = ' ${normalize(text)} ';
    if (words.trim().isEmpty) return null;
    for (final brand in all) {
      for (final alias in brand.aliases) {
        if (words.contains(' $alias ')) return brand;
      }
    }
    return null;
  }

  /// Lower case, letters and digits only, single spaces: "H.P. Petrol-Pump"
  /// becomes "h p petrol pump", with dotted initials ("H.P.", "I.O.C.L.")
  /// joined into one word.
  static String normalize(String text) {
    final joined = text.replaceAllMapped(
      RegExp(r'\b(?:[A-Za-z]\.){2,}'),
      (m) => m[0]!.replaceAll('.', ''),
    );
    return joined
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), ' ')
        .trim();
  }
}
