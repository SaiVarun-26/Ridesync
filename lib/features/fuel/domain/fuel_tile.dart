import 'dart:math' as math;

import '../../ride/domain/geo_point.dart';

/// One square of a fixed, world-wide quadtree that fuel searches are made
/// in.
///
/// An area ([level] 0) is [rootSize] degrees, about 9 km. Where a search
/// comes back capped (a dense city centre), the square is split into four
/// and each quarter searched on its own, down to [maxLevel] (about 1 km).
/// Because the grid is fixed, the same square is the same square on every
/// ride and every phone, which is what makes results cacheable and stops the
/// same ground being searched twice.
class FuelTile {
  const FuelTile(this.level, this.row, this.column);

  /// The area holding [point].
  factory FuelTile.rootOf(GeoPoint point) => FuelTile(
    0,
    (point.latitude / rootSize).floor(),
    (point.longitude / rootSize).floor(),
  );

  static const double rootSize = 0.08;
  static const int maxLevel = 3;

  final int level;
  final int row;
  final int column;

  double get size => rootSize / (1 << level);
  double get south => row * size;
  double get north => (row + 1) * size;
  double get west => column * size;
  double get east => (column + 1) * size;

  GeoPoint get center =>
      GeoPoint(latitude: south + size / 2, longitude: west + size / 2);

  /// From the centre to a corner: a search this wide covers the square.
  double get halfDiagonalMeters =>
      center.distanceMetersTo(GeoPoint(latitude: north, longitude: east));

  bool contains(GeoPoint p) =>
      p.latitude >= south &&
      p.latitude < north &&
      p.longitude >= west &&
      p.longitude < east;

  /// The area (level 0) this square belongs to.
  FuelTile get root =>
      level == 0 ? this : FuelTile(0, row >> level, column >> level);

  List<FuelTile> get children => [
    for (final dr in const [0, 1])
      for (final dc in const [0, 1])
        FuelTile(level + 1, row * 2 + dr, column * 2 + dc),
  ];

  /// How far [p] is from the nearest point of the square (0 inside).
  double distanceMetersTo(GeoPoint p) {
    final lat = p.latitude.clamp(south, north);
    final lng = p.longitude.clamp(west, east);
    return p.distanceMetersTo(GeoPoint(latitude: lat, longitude: lng));
  }

  /// Every area within [radiusMeters] of [p].
  static List<FuelTile> rootsWithin(GeoPoint p, double radiusMeters) {
    final dLat = radiusMeters / 111320;
    final dLng =
        radiusMeters / (111320 * math.max(0.01, math.cos(p.latitude * math.pi / 180)));
    final r0 = ((p.latitude - dLat) / rootSize).floor();
    final r1 = ((p.latitude + dLat) / rootSize).floor();
    final c0 = ((p.longitude - dLng) / rootSize).floor();
    final c1 = ((p.longitude + dLng) / rootSize).floor();
    return [
      for (var r = r0; r <= r1; r++)
        for (var c = c0; c <= c1; c++)
          if (FuelTile(0, r, c).distanceMetersTo(p) <= radiusMeters)
            FuelTile(0, r, c),
    ];
  }

  String get key => 'fuel_t${level}_${row}_$column';

  @override
  bool operator ==(Object other) =>
      other is FuelTile &&
      other.level == level &&
      other.row == row &&
      other.column == column;

  @override
  int get hashCode => Object.hash(level, row, column);

  @override
  String toString() => 'L$level($row,$column)';
}
