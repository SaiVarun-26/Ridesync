import '../geo_point.dart';

/// A recorded path: where the rider went, how fast, and when.
class RecordedPath {
  const RecordedPath({
    this.points = const [],
    this.speedsMps = const [],
    this.timesMs = const [],
  });

  final List<GeoPoint> points;

  /// Ground speed in meters per second at each point, in step with [points].
  /// Empty when speeds were not recorded.
  final List<double> speedsMps;

  /// When the rider was at each point (epoch millis), in step with [points].
  /// Empty for rides recorded before times were kept.
  final List<int> timesMs;

  bool get hasSpeeds => points.isNotEmpty && speedsMps.length == points.length;

  bool get hasTimes => points.isNotEmpty && timesMs.length == points.length;
}

/// The rider's whole-ride path, kept compact enough to save and restore.
///
/// A point is recorded only after the rider has moved [spacingMeters] from the
/// previous one, together with their speed and the time there. If the path
/// outgrows [maxPoints] it is thinned by half and the spacing doubles, so
/// memory and storage stay bounded however long the ride is while the overall
/// shape is kept. Unlike the on-screen trail, this never fades: it is the
/// record used for the ride summary, the results and the replay.
class RecordedRoute {
  RecordedRoute({RecordedPath initial = const RecordedPath()}) {
    restore(initial);
  }

  static const int maxPoints = 3000;
  static const double baseSpacingMeters = 25;

  final List<GeoPoint> _points = [];
  final List<double> _speeds = [];

  /// 0 marks a point whose time is unknown (restored from an older save).
  final List<int> _times = [];
  double _spacing = baseSpacingMeters;
  int _version = 0;

  /// The recorded points, oldest first.
  List<GeoPoint> get points => List<GeoPoint>.unmodifiable(_points);

  /// The recorded path with its speeds and, when every point has one, times.
  RecordedPath get path => RecordedPath(
    points: List<GeoPoint>.unmodifiable(_points),
    speedsMps: List<double>.unmodifiable(_speeds),
    timesMs: _times.contains(0) ? const [] : List<int>.unmodifiable(_times),
  );

  /// Increases whenever the route changes, so callers can tell if it needs
  /// saving.
  int get version => _version;

  /// Replaces the route with a previously saved [path]. A path saved without
  /// speeds restores with zero speeds, and one without times with unknown
  /// times.
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
    _times
      ..clear()
      ..addAll(
        path.hasTimes ? path.timesMs : List<int>.filled(path.points.length, 0),
      );
    _spacing = baseSpacingMeters;
    while (_points.length > maxPoints) {
      _thin();
    }
  }

  /// Records [point], the rider's [speedMps] and the time [atMs] if they have
  /// moved far enough. Returns whether it was added.
  bool add(GeoPoint point, {double speedMps = 0, int atMs = 0}) {
    if (_points.isNotEmpty && _points.last.distanceMetersTo(point) < _spacing) {
      return false;
    }
    _points.add(point);
    _speeds.add(speedMps < 0 ? 0 : speedMps);
    _times.add(atMs);
    if (_points.length > maxPoints) _thin();
    _version++;
    return true;
  }

  void _thin() {
    final lastPoint = _points.last;
    final lastSpeed = _speeds.last;
    final lastTime = _times.last;
    final points = <GeoPoint>[];
    final speeds = <double>[];
    final times = <int>[];
    for (var i = 0; i < _points.length; i += 2) {
      points.add(_points[i]);
      // A dropped neighbour's speed is folded in, so thinning smooths the
      // speeds instead of throwing them away. A kept point keeps its time.
      speeds.add(
        i + 1 < _speeds.length ? (_speeds[i] + _speeds[i + 1]) / 2 : _speeds[i],
      );
      times.add(_times[i]);
    }
    if (points.last != lastPoint) {
      points.add(lastPoint);
      speeds.add(lastSpeed);
      times.add(lastTime);
    }
    _points
      ..clear()
      ..addAll(points);
    _speeds
      ..clear()
      ..addAll(speeds);
    _times
      ..clear()
      ..addAll(times);
    _spacing *= 2;
  }
}
