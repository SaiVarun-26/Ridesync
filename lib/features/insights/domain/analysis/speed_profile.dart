import 'dart:math' as math;

import '../../../history/domain/speed_scale.dart';
import '../../../ride/domain/geo_point.dart';

/// A stretch of a route between two distances from its start.
class RouteSegment {
  const RouteSegment({
    required this.startMeters,
    required this.endMeters,
    required this.averageSpeedMps,
  });

  final double startMeters;
  final double endMeters;
  final double averageSpeedMps;

  double get lengthMeters => endMeters - startMeters;
}

/// How one rider's speed behaved over their route.
///
/// Routes are recorded as points every 25 m or so, each with the speed there,
/// but no timestamps. Everything here is therefore measured along the route
/// by distance rather than by time, which is what matters for describing a
/// ride anyway ("the fastest kilometre", "18 km without slowing").
class SpeedProfile {
  const SpeedProfile({
    required this.distanceMeters,
    required this.averageMovingSpeedMps,
    required this.smoothness,
    required this.consistency,
    required this.sprintSpeedMps,
    required this.longestContinuousMeters,
    required this.slowdowns,
    required this.topSpeedFraction,
    this.fastest,
    this.slowest,
  });

  /// Length of the analysed route.
  final double distanceMeters;

  /// Distance-weighted average of the speeds recorded while moving.
  final double averageMovingSpeedMps;

  /// 0–100: how gently speed changed. High for a flowing ride, low for one
  /// full of sharp braking, surges and near-stops.
  final double smoothness;

  /// 0–100: how evenly the pace was held. High when the rider rode at much
  /// the same speed throughout.
  final double consistency;

  /// Best average speed over a short (about 200 m) stretch.
  final double sprintSpeedMps;

  /// Longest stretch ridden without slowing to a crawl or stopping.
  final double longestContinuousMeters;

  /// How many times the rider slowed to a crawl or stopped.
  final int slowdowns;

  /// Where on the route the top recorded speed came, from 0 (start) to 1
  /// (end).
  final double topSpeedFraction;

  final RouteSegment? fastest;
  final RouteSegment? slowest;
}

/// Works out a [SpeedProfile] from a recorded route. Pure and fast: a single
/// pass plus two sliding windows over at most a few thousand points.
abstract final class SpeedAnalyzer {
  /// Below this the rider is crawling or stopped.
  static const double crawlSpeedMps = 1.5;

  /// The fastest/slowest stretch is this share of the route, kept between
  /// [_minWindowMeters] and [_maxWindowMeters].
  static const double _windowShare = 0.1;
  static const double _minWindowMeters = 300;
  static const double _maxWindowMeters = 2000;

  /// A sprint is the best average over this distance.
  static const double _sprintMeters = 200;

  /// A slowest stretch must be at least this much moving, so a traffic light
  /// does not count as "the slowest kilometre".
  static const double _minMovingShare = 0.7;

  /// Changes in speed smaller than this between neighbouring points are
  /// recording noise and do not count against smoothness.
  static const double _noiseMps = 0.25;

  /// Average speed change (m/s per point) at which smoothness falls to
  /// about a third.
  static const double _roughnessScale = 1.1;

  /// Coefficient of variation of speed at which consistency reaches zero.
  static const double _cvAtZero = 0.6;

  /// Routes shorter than this tell too little to analyse.
  static const double minRouteMeters = 300;

  /// The profile for [points] and their [speedsMps], or `null` when the route
  /// is too short or has no speeds recorded.
  static SpeedProfile? analyze(List<GeoPoint> points, List<double> speedsMps) {
    final n = points.length;
    if (n < 3 || speedsMps.length != n) return null;
    final speeds = SpeedScale.smooth(speedsMps, radius: 2);

    // Distance from the start to each point.
    final along = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      along[i] = along[i - 1] + points[i - 1].distanceMetersTo(points[i]);
    }
    final total = along.last;
    if (total < minRouteMeters) return null;

    var movingDistance = 0.0;
    var weighted = 0.0;
    var weightedSquares = 0.0;
    var roughness = 0.0;
    var roughCount = 0;
    var slowdowns = 0;
    var run = 0.0;
    var longestRun = 0.0;
    var crawling = speeds.first < crawlSpeedMps;
    var top = 0.0;
    var topIndex = 0;

    for (var i = 1; i < n; i++) {
      final length = along[i] - along[i - 1];
      final speed = (speeds[i - 1] + speeds[i]) / 2;
      if (speeds[i] > top) {
        top = speeds[i];
        topIndex = i;
      }
      final nowCrawling = speeds[i] < crawlSpeedMps;
      if (nowCrawling && !crawling) slowdowns++;
      crawling = nowCrawling;
      if (nowCrawling) {
        longestRun = math.max(longestRun, run);
        run = 0;
      } else {
        run += length;
      }
      if (speed >= crawlSpeedMps) {
        movingDistance += length;
        weighted += speed * length;
        weightedSquares += speed * speed * length;
        final change = (speeds[i] - speeds[i - 1]).abs();
        roughness += change > _noiseMps ? change : 0;
        roughCount++;
      }
    }
    longestRun = math.max(longestRun, run);

    final mean = movingDistance > 0 ? weighted / movingDistance : 0.0;
    final variance = movingDistance > 0
        ? math.max(0.0, weightedSquares / movingDistance - mean * mean)
        : 0.0;
    final cv = mean > 0 ? math.sqrt(variance) / mean : 1.0;
    final consistency = 100 * (1 - cv / _cvAtZero).clamp(0.0, 1.0);

    final meanChange = roughCount > 0 ? roughness / roughCount : 0.0;
    // Every slowdown per kilometre also costs a little flow.
    final slowdownsPerKm = slowdowns / (total / 1000);
    final smoothness =
        (100 * math.exp(-meanChange / _roughnessScale) -
                math.min(25.0, slowdownsPerKm * 6))
            .clamp(0.0, 100.0);

    final window = (total * _windowShare).clamp(
      _minWindowMeters,
      _maxWindowMeters,
    );
    final windows = window < total
        ? _windows(along, speeds, window)
        : const <_Window>[];
    _Window? fastest;
    _Window? slowest;
    for (final w in windows) {
      if (fastest == null || w.average > fastest.average) fastest = w;
      if (w.movingShare >= _minMovingShare &&
          (slowest == null || w.average < slowest.average)) {
        slowest = w;
      }
    }
    final sprints = _sprintMeters < total
        ? _windows(along, speeds, _sprintMeters)
        : const <_Window>[];
    final sprint = sprints.fold<double>(
      0,
      (best, w) => math.max(best, w.average),
    );

    return SpeedProfile(
      distanceMeters: total,
      averageMovingSpeedMps: mean,
      smoothness: smoothness,
      consistency: consistency,
      sprintSpeedMps: sprint,
      longestContinuousMeters: longestRun,
      slowdowns: slowdowns,
      topSpeedFraction: total > 0 ? along[topIndex] / total : 0,
      fastest: fastest?.segment,
      slowest: slowest?.segment,
    );
  }

  /// Average speed over every stretch of [length] metres, sliding one point
  /// at a time.
  static List<_Window> _windows(
    List<double> along,
    List<double> speeds,
    double length,
  ) {
    final n = along.length;
    final result = <_Window>[];
    var start = 0;
    var sum = 0.0;
    var moving = 0.0;
    for (var end = 1; end < n; end++) {
      final segment = along[end] - along[end - 1];
      final speed = (speeds[end - 1] + speeds[end]) / 2;
      sum += speed * segment;
      if (speed >= crawlSpeedMps) moving += segment;
      while (along[end] - along[start] > length && start < end - 1) {
        final drop = along[start + 1] - along[start];
        final dropSpeed = (speeds[start] + speeds[start + 1]) / 2;
        sum -= dropSpeed * drop;
        if (dropSpeed >= crawlSpeedMps) moving -= drop;
        start++;
      }
      final span = along[end] - along[start];
      if (span >= length * 0.9) {
        result.add(
          _Window(along[start], along[end], sum / span, moving / span),
        );
      }
    }
    return result;
  }
}

class _Window {
  const _Window(this.start, this.end, this.average, this.movingShare);

  final double start;
  final double end;
  final double average;
  final double movingShare;

  RouteSegment get segment => RouteSegment(
    startMeters: start,
    endMeters: end,
    averageSpeedMps: average,
  );
}
