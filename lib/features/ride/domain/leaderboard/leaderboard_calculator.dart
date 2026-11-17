import 'dart:math' as math;

import '../geo_point.dart';
import '../guidance/off_route_detector.dart';
import '../guidance/route_geometry.dart';
import '../guidance/route_simplifier.dart';
import '../live/rider_trail.dart';
import 'leaderboard.dart';

/// Ranks the riders of a live ride by how far along they are, and notices
/// riders leaving and rejoining the path. Pure Dart, driven by the caller.
///
/// **Ranking.** Everyone is placed on one path and ordered by how far along
/// it they are. Who hosts, who joined first, rider ids and database order play
/// no part, and neither does total distance ridden, so a late joiner ranks by
/// where they are.
/// - Guided ride: the planned route.
/// - Free roam: the group's path, which is the ridden trail (continued a
///   little past its end) that the most riders are on. The leader's trail
///   usually holds everyone behind them, so it is usually the one.
///
/// **Leaving and rejoining.** In a guided ride a rider is off the path when
/// they are away from the planned route. In free roam a rider is off it when
/// they are away from every trail the group shares; a rider whose own trail
/// holds the group (the one everybody follows) is never off it. Each rider
/// has an [OffRouteDetector], so one bad reading never counts and the state
/// only changes past a margin both ways. An event fires once per change, and
/// a "rejoined" event only follows a "left" one.
///
/// Positions only change on GPS updates, so this runs then, never per frame.
/// Each trail is simplified and measured once and reused until it changes.
class LeaderboardCalculator {
  LeaderboardCalculator({
    OffRouteDetector Function()? guidedDetector,
    OffRouteDetector Function()? groupDetector,
  }) : _guidedDetector = guidedDetector ?? _defaultGuided,
       _groupDetector = groupDetector ?? _defaultGroup;

  final OffRouteDetector Function() _guidedDetector;
  final OffRouteDetector Function() _groupDetector;

  static OffRouteDetector _defaultGuided() => OffRouteDetector(leaveMeters: 50);

  static OffRouteDetector _defaultGroup() => OffRouteDetector(
    leaveMeters: 70,
    rejoinMeters: 30,
    confirmTime: const Duration(seconds: 6),
  );

  /// A rider this close to a path is on it.
  static const double onPathMeters = 40;

  /// A guided rider this close to the route shares it for measuring gaps.
  static const double onRouteMeters = 60;

  /// How far past its end a trail is continued straight on.
  static const double extensionMeters = 250;

  /// Riders closer than this along the path keep their order.
  static const double orderDeadbandMeters = 6;

  /// After an event about a rider, a new "left" is not announced for this
  /// long, so a rider weaving at the edge of the margin does not spam.
  static const Duration eventCooldown = Duration(seconds: 20);

  /// Longest stretch of a trail used as a path, and how much it is
  /// simplified. Older ground adds nothing.
  static const double _maxTrailMeters = 3000;
  static const double _simplifyMeters = 2;
  static const double _minPathMeters = 12;

  /// Below this a rider is stopped.
  static const double _movingMps = 1;

  final Map<String, _Track> _tracks = {};
  final Map<String, (RiderTrail, RouteGeometry?)> _geometry = {};
  List<String> _order = const [];

  /// The ranking for [riders] now. [route] is the guided ride's planned route;
  /// `null` in free roam.
  LeaderboardResult update({
    required List<LeaderboardRider> riders,
    RouteGeometry? route,
    required int nowMs,
  }) {
    final present = {for (final r in riders) r.uid};
    // A rider who goes offline starts afresh when they come back.
    _tracks.removeWhere((uid, _) => !present.contains(uid));
    _geometry.removeWhere((uid, _) => !present.contains(uid));
    if (riders.isEmpty) {
      _order = const [];
      return const LeaderboardResult(entries: [], events: []);
    }

    final guided = route != null && route.isUsable;
    final measure = guided
        ? _measureOnRoute(riders, route)
        : _measureOnGroupPath(riders);

    final events = <RidePathEvent>[];
    for (final rider in riders) {
      final track = _tracks.putIfAbsent(
        rider.uid,
        () => _Track(guided ? _guidedDetector() : _groupDetector(), guided),
      );
      if (track.guided != guided) {
        // The route arrived (or went): judge against the new path from now.
        _tracks[rider.uid] = _Track(
          guided ? _guidedDetector() : _groupDetector(),
          guided,
        );
        continue;
      }
      final offset = measure.offPathOffset[rider.uid];
      // Only a new position is a new reading.
      if (offset == null || rider.point.samePlaceAs(track.lastPoint)) continue;
      track.lastPoint = rider.point;
      final wasOff = track.detector.isOffRoute;
      final isOff = track.detector.update(
        offset,
        accuracyMeters: rider.point.accuracyMeters,
        timeMs: nowMs,
      );
      if (!wasOff && isOff) {
        final quiet = nowMs - track.lastEventMs >= eventCooldown.inMilliseconds;
        if (quiet) {
          track
            ..announcedLeft = true
            ..lastEventMs = nowMs;
          events.add(
            RidePathEvent(
              uid: rider.uid,
              kind: RidePathEventKind.left,
              atMs: nowMs,
              guided: guided,
              point: rider.point,
            ),
          );
        }
      } else if (wasOff && !isOff && track.announcedLeft) {
        track
          ..announcedLeft = false
          ..lastEventMs = nowMs;
        events.add(
          RidePathEvent(
            uid: rider.uid,
            kind: RidePathEventKind.rejoined,
            atMs: nowMs,
            guided: guided,
            point: rider.point,
          ),
        );
      }
    }

    _order = _rank(riders, measure.progress);
    final me = riders.where((r) => r.isMe).firstOrNull;
    final myProgress = me == null ? null : measure.progress[me.uid];
    final meShares = me != null && measure.sharesPath.contains(me.uid);
    final byUid = {for (final r in riders) r.uid: r};
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < _order.length; i++) {
      final rider = byUid[_order[i]]!;
      final progress = measure.progress[rider.uid];
      final speed = rider.speedMps ?? 0;
      entries.add(
        LeaderboardEntry(
          uid: rider.uid,
          rank: i + 1,
          isMe: rider.isMe,
          speedMps: speed < _movingMps ? 0 : speed,
          isOffPath: _tracks[rider.uid]?.detector.isOffRoute ?? false,
          gapMeters:
              !rider.isMe &&
                  meShares &&
                  myProgress != null &&
                  progress != null &&
                  measure.sharesPath.contains(rider.uid)
              ? progress - myProgress
              : null,
        ),
      );
    }
    return LeaderboardResult(entries: entries, events: events);
  }

  /// Guided: everyone on the planned route.
  _Measure _measureOnRoute(List<LeaderboardRider> riders, RouteGeometry route) {
    final measure = _Measure();
    for (final rider in riders) {
      final projection = route.project(rider.point);
      measure.progress[rider.uid] = projection.alongMeters;
      measure.offPathOffset[rider.uid] = projection.offsetMeters;
      if (projection.offsetMeters <= onRouteMeters) {
        measure.sharesPath.add(rider.uid);
      }
    }
    return measure;
  }

  /// Free roam: everyone on the group's path, worked out from the trails.
  _Measure _measureOnGroupPath(List<LeaderboardRider> riders) {
    final measure = _Measure();
    final paths = <String, RouteGeometry>{};
    for (final rider in riders) {
      final path = _pathOf(rider);
      if (path != null) paths[rider.uid] = path;
    }
    if (paths.isEmpty) return _measureByCourse(riders);

    // Where every rider sits on every path, and how many each path holds.
    final along = <String, Map<String, double>>{};
    final offset = <String, Map<String, double>>{};
    final score = <String, double>{};
    for (final entry in paths.entries) {
      final path = entry.value;
      final a = <String, double>{};
      final o = <String, double>{};
      var covered = 0;
      for (final rider in riders) {
        final p = path.projectExtended(rider.point);
        a[rider.uid] = p.alongMeters;
        final beyond =
            p.alongMeters > path.lengthMeters + extensionMeters ||
            p.alongMeters < -extensionMeters;
        final distance = beyond ? double.infinity : p.offsetMeters;
        o[rider.uid] = distance;
        if (distance <= onPathMeters) covered++;
      }
      along[entry.key] = a;
      offset[entry.key] = o;
      // When paths hold as many riders each, this rider's own view decides.
      final mine = riders.any((r) => r.isMe && r.uid == entry.key);
      score[entry.key] = covered + (mine ? 0.5 : 0);
    }

    String? best;
    for (final uid in paths.keys) {
      if (best == null ||
          score[uid]! > score[best]! ||
          (score[uid] == score[best] &&
              paths[uid]!.lengthMeters > paths[best]!.lengthMeters)) {
        best = uid;
      }
    }
    final bestScore = score[best]!;
    for (final rider in riders) {
      measure.progress[rider.uid] = along[best]![rider.uid]!;
      if (offset[best]![rider.uid]! <= onPathMeters) {
        measure.sharesPath.add(rider.uid);
      }

      // Off the group's path? A rider whose own trail holds the group is
      // what the group follows; anyone else is judged against the trails
      // the group shares.
      final own = score[rider.uid] ?? 0;
      if (own >= bestScore) {
        measure.offPathOffset[rider.uid] = 0;
        continue;
      }
      double? nearest;
      for (final uid in paths.keys) {
        if (uid == rider.uid || score[uid]! < 1.5) continue;
        final d = offset[uid]![rider.uid]!;
        nearest = nearest == null ? d : math.min(nearest, d);
      }
      if (nearest != null) {
        // A finite reading so the detector can count it; any distance this
        // large is far off the path.
        measure.offPathOffset[rider.uid] = nearest.isFinite ? nearest : 1e6;
      }
    }
    return measure;
  }

  /// No trails yet (the ride has just begun): order along the group's mean
  /// direction of travel, from where the group is. Nobody can be off a path
  /// that does not exist yet.
  _Measure _measureByCourse(List<LeaderboardRider> riders) {
    final measure = _Measure();
    var x = 0.0;
    var y = 0.0;
    var lat = 0.0;
    var lng = 0.0;
    for (final rider in riders) {
      lat += rider.point.latitude;
      lng += rider.point.longitude;
    }
    final centre = GeoPoint(
      latitude: lat / riders.length,
      longitude: lng / riders.length,
    );
    // The mean heading, from the riders moving fast enough to have one.
    var moving = 0;
    for (final rider in riders) {
      final trail = rider.trail?.points;
      if ((rider.speedMps ?? 0) < _movingMps || trail == null) continue;
      if (trail.length < 2) continue;
      final b = trail[trail.length - 2].point.bearingDegreesTo(trail.last.point);
      x += math.sin(b * math.pi / 180);
      y += math.cos(b * math.pi / 180);
      moving++;
    }
    if (moving == 0 || (x == 0 && y == 0)) return measure;
    final heading = math.atan2(x, y);
    for (final rider in riders) {
      final d = centre.distanceMetersTo(rider.point);
      final bearing = centre.bearingDegreesTo(rider.point) * math.pi / 180;
      measure.progress[rider.uid] = d * math.cos(bearing - heading);
      measure.sharesPath.add(rider.uid);
    }
    return measure;
  }

  /// The rider's current stretch of trail as a measured line, built once per
  /// trail.
  RouteGeometry? _pathOf(LeaderboardRider rider) {
    final trail = rider.trail;
    if (trail == null) return null;
    final cached = _geometry[rider.uid];
    if (cached != null && identical(cached.$1, trail)) return cached.$2;
    final points = trail.points;
    var from = 0;
    for (var i = points.length - 1; i > 0; i--) {
      if (points[i].startsSegment) {
        from = i;
        break;
      }
    }
    // Newest first, back to the longest stretch kept.
    final kept = <GeoPoint>[];
    var meters = 0.0;
    for (var i = points.length - 1; i >= from; i--) {
      final p = points[i].point;
      if (kept.isNotEmpty) meters += kept.last.distanceMetersTo(p);
      if (meters > _maxTrailMeters) break;
      kept.add(p);
    }
    RouteGeometry? path;
    if (kept.length >= 2) {
      final line = RouteGeometry(
        RouteSimplifier.simplify(
          kept.reversed.toList(),
          toleranceMeters: _simplifyMeters,
        ),
      );
      if (line.isUsable && line.lengthMeters >= _minPathMeters) path = line;
    }
    _geometry[rider.uid] = (trail, path);
    return path;
  }

  /// The new order: the last one, with neighbours swapped only when the one
  /// behind is clearly further along, so riders side by side do not flicker.
  /// Riders new to the board are placed where they belong straight away.
  List<String> _rank(
    List<LeaderboardRider> riders,
    Map<String, double> progress,
  ) {
    final present = {for (final r in riders) r.uid};
    final order = [
      for (final uid in _order)
        if (present.contains(uid)) uid,
    ];
    final known = order.toSet();
    final fresh = [
      for (final r in riders)
        if (!known.contains(r.uid)) r.uid,
    ];
    double value(String uid) => progress[uid] ?? double.negativeInfinity;
    for (final uid in fresh) {
      var at = order.length;
      for (var i = 0; i < order.length; i++) {
        if (value(uid) > value(order[i])) {
          at = i;
          break;
        }
      }
      order.insert(at, uid);
    }
    if (progress.isEmpty) return order;
    var swapped = true;
    for (var pass = 0; swapped && pass < order.length; pass++) {
      swapped = false;
      for (var i = 0; i + 1 < order.length; i++) {
        if (value(order[i + 1]) > value(order[i]) + orderDeadbandMeters) {
          final t = order[i];
          order[i] = order[i + 1];
          order[i + 1] = t;
          swapped = true;
        }
      }
    }
    return order;
  }
}

class _Track {
  _Track(this.detector, this.guided);

  final OffRouteDetector detector;
  final bool guided;
  GeoPoint lastPoint = const GeoPoint(latitude: 1000, longitude: 1000);
  bool announcedLeft = false;
  int lastEventMs = -1 << 40;
}

class _Measure {
  /// Distance along the shared path, by uid.
  final Map<String, double> progress = {};

  /// Riders on the shared path, between whom a gap means something.
  final Set<String> sharesPath = {};

  /// How far each rider is from the path, for off-path detection; absent
  /// when it cannot be judged.
  final Map<String, double> offPathOffset = {};
}
