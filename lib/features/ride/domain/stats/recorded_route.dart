import '../geo_point.dart';

/// A recorded path: where the rider went and how fast at each point.
class RecordedPath {
  const RecordedPath({this.points = const [], this.speedsMps = const []});

  final List<GeoPoint> points;

  /// Ground speed in meters per second at each point, in step with [points].
  /// Empty when speeds were not recorded.
  final List<double> speedsMps;

  bool get hasSpeeds => points.isNotEmpty && speedsMps.length == points.length;
}

/// The rider's whole-ride path, kept compact enough to save and restore.
///
/// A point is recorded only after the rider has moved [spacingMeters] from the
/// previous one, together with their speed there. If the path outgrows
/// [maxPoints] it is thinned by half and the spacing doubles, so memory and
/// storage stay bounded however long the ride is while the overall shape is
/// kept. Unlike the on-screen trail, this never fades: it is the record used
/// for the ride summary.
class RecordedRoute {
  RecordedRoute({RecordedPath initial = const RecordedPath()}) {
    restore(initial);
  }

  static const int maxPoints = 3000;
  static const double baseSpacingMeters = 25;

  final List<GeoPoint> _points = [];
  final List<double> _speeds = [];
  double _spacing = baseSpacingMeters;
  int _version = 0;

  /// The recorded points, oldest first.
  List<GeoPoint> get points => List<GeoPoint>.unmodifiable(_points);

  /// The recorded path with its speeds.
  RecordedPath get path => RecordedPath(
    points: List<GeoPoint>.unmodifiable(_points),
    speedsMps: List<double>.unmodifiable(_speeds),
  );

  /// Increases whenever the route changes, so callers can tell if it needs
  /// saving.
  int get version => _version;

  /// Replaces the route with a previously saved [path]. A path saved without
  /// speeds restores with zero speeds.
  void restore(RecordedPath path) {
    _points
      ..clear()
      ..addAll(path.points);
    _speeds
      ..clear()
      ..addAll(
        path.hasSpeeds
            ? path.speedsMps
            : List<double>.filled(path.points.length, 0),
      );
    _spacing = baseSpacingMeters;
    while (_points.length > maxPoints) {
      _thin();
    }
  }

  /// Records [point] and the rider's [speedMps] if they have moved far
  /// enough. Returns whether it was added.
  bool add(GeoPoint point, {double speedMps = 0}) {
    if (_points.isNotEmpty && _points.last.distanceMetersTo(point) < _spacing) {
      return false;
    }
    _points.add(point);
    _speeds.add(speedMps < 0 ? 0 : speedMps);
    if (_points.length > maxPoints) _thin();
    _version++;
    return true;
  }

  void _thin() {
    final lastPoint = _points.last;
    final lastSpeed = _speeds.last;
    final points = <GeoPoint>[];
    final speeds = <double>[];
    for (var i = 0; i < _points.length; i += 2) {
      points.add(_points[i]);
      // A dropped neighbour's speed is folded in, so thinning smooths the
      // speeds instead of throwing them away.
      speeds.add(
        i + 1 < _speeds.length ? (_speeds[i] + _speeds[i + 1]) / 2 : _speeds[i],
      );
    }
    if (points.last != lastPoint) {
      points.add(lastPoint);
      speeds.add(lastSpeed);
    }
    _points
      ..clear()
      ..addAll(points);
    _speeds
      ..clear()
      ..addAll(speeds);
    _spacing *= 2;
  }
}
