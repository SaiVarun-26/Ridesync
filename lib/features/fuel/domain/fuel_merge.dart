import '../../ride/domain/geo_point.dart';
import 'fuel_station.dart';

/// Merges fuel stations from several searches and providers into one set,
/// each pump once.
///
/// Two entries are the same pump when they have the same OpenStreetMap id,
/// or when they are within [nearMeters] of each other and their names agree
/// (or one has none): the same forecourt mapped once as a point and once as
/// an area. The named entry is kept.
abstract final class FuelMerge {
  static const double nearMeters = 35;

  /// Adds [incoming] to [into] (by id). Returns (added, duplicates), where
  /// duplicates counts entries already present by id or as a near match.
  /// [onKept] is told the id that stands for each incoming entry.
  static (int, int) addAll(
    Map<String, FuelStation> into,
    Iterable<FuelStation> incoming, {
    void Function(String id)? onKept,
  }) {
    var added = 0;
    var duplicates = 0;
    final grid = _Grid()..addAll(into.values);
    for (final s in incoming) {
      final existing = into[s.id] ?? grid.nearMatch(s);
      if (existing != null) {
        duplicates++;
        // Keep what either entry knows: a name, a brand, an operator.
        if ((existing.name == null && s.name != null) ||
            (existing.brand == null && s.brand != null) ||
            (existing.operator == null && s.operator != null)) {
          final filled = existing.withDetailsFrom(s);
          into[existing.id] = filled;
          grid.replace(existing, filled);
        }
        onKept?.call(existing.id);
        continue;
      }
      into[s.id] = s;
      grid.add(s);
      added++;
      onKept?.call(s.id);
    }
    return (added, duplicates);
  }

  /// [stations] with duplicates removed: (unique, removed).
  static (List<FuelStation>, int) dedupe(Iterable<FuelStation> stations) {
    final out = <String, FuelStation>{};
    final (_, removed) = addAll(out, stations);
    return (out.values.toList(), removed);
  }

  static bool sameName(String? a, String? b) {
    if (a == null || b == null) return true;
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final x = norm(a);
    final y = norm(b);
    return x.isEmpty || y.isEmpty || x.contains(y) || y.contains(x);
  }
}

/// A coarse spatial hash for near-duplicate lookups (cells ~ 40 m).
class _Grid {
  static const double _cell = 0.00036;
  final Map<(int, int), List<FuelStation>> _cells = {};

  (int, int) _key(GeoPoint p) =>
      ((p.latitude / _cell).floor(), (p.longitude / _cell).floor());

  void add(FuelStation s) => (_cells[_key(s.point)] ??= []).add(s);

  void addAll(Iterable<FuelStation> stations) => stations.forEach(add);

  void replace(FuelStation old, FuelStation next) {
    final list = _cells[_key(old.point)];
    if (list == null) return;
    final i = list.indexWhere((s) => s.id == old.id);
    if (i >= 0) list[i] = next;
  }

  FuelStation? nearMatch(FuelStation s) {
    final (r, c) = _key(s.point);
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        for (final other in _cells[(r + dr, c + dc)] ?? const <FuelStation>[]) {
          if (other.id == s.id) return other;
          if (other.point.distanceMetersTo(s.point) <= FuelMerge.nearMeters &&
              FuelMerge.sameName(other.name, s.name)) {
            return other;
          }
        }
      }
    }
    return null;
  }
}
