import '../geo_point.dart';

/// The rider's whole-ride path, kept compact enough to save and restore.
///
/// A point is recorded only after the rider has moved [spacingMeters] from the
/// previous one. If the path outgrows [maxPoints] it is thinned by half and the
/// spacing doubles, so memory and storage stay bounded however long the ride
/// is while the overall shape is kept. Unlike the on-screen trail, this never
/// fades: it is the record used for the ride summary.
class RecordedRoute {
  RecordedRoute({List<GeoPoint> initial = const []}) {
    restore(initial);
  }

  static const int maxPoints = 3000;
  static const double baseSpacingMeters = 25;

  final List<GeoPoint> _points = [];
  double _spacing = baseSpacingMeters;
  int _version = 0;

  /// The recorded points, oldest first.
  List<GeoPoint> get points => List<GeoPoint>.unmodifiable(_points);

  /// Increases whenever the route changes, so callers can tell if it needs
  /// saving.
  int get version => _version;

  /// Replaces the route with previously saved [points].
  void restore(List<GeoPoint> points) {
    _points
      ..clear()
      ..addAll(points);
    _spacing = baseSpacingMeters;
    while (_points.length > maxPoints) {
      _thin();
    }
  }

  /// Records [point] if the rider has moved far enough. Returns whether it was
  /// added.
  bool add(GeoPoint point) {
    if (_points.isNotEmpty &&
        _points.last.distanceMetersTo(point) < _spacing) {
      return false;
    }
    _points.add(point);
    if (_points.length > maxPoints) _thin();
    _version++;
    return true;
  }

  void _thin() {
    final last = _points.last;
    final kept = <GeoPoint>[
      for (var i = 0; i < _points.length; i += 2) _points[i],
    ];
    if (kept.last != last) kept.add(last);
    _points
      ..clear()
      ..addAll(kept);
    _spacing *= 2;
  }
}
