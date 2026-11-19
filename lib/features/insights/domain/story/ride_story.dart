import 'dart:math' as math;

import '../../../ride/domain/geo_point.dart';

/// One rider's route laid out in time, for the replay and for anything that
/// asks "where was everyone at this moment?".
class RideTrace {
  RideTrace({
    required this.uid,
    required this.points,
    required this.timesMs,
    required this.alongMeters,
    required this.speedsMps,
    required this.estimated,
  });

  final String uid;
  final List<GeoPoint> points;

  /// When the rider was at each point (epoch millis), never decreasing.
  final List<int> timesMs;

  /// Distance from the start to each point.
  final List<double> alongMeters;

  /// Speed at each point; empty when not recorded.
  final List<double> speedsMps;

  /// Whether [timesMs] were worked out from speeds (rides recorded before
  /// times were kept) rather than recorded.
  final bool estimated;

  int get startMs => timesMs.first;
  int get endMs => timesMs.last;
  double get lengthMeters => alongMeters.last;

  /// Where the rider was at [timeMs]: before their start they are at the
  /// start, after their end at the end.
  TracePosition at(int timeMs) {
    final n = timesMs.length;
    if (n == 1 || timeMs <= timesMs.first) return _position(0, 0);
    if (timeMs >= timesMs.last) return _position(n - 1, 0);
    var lo = 0;
    var hi = n - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (timesMs[mid] <= timeMs) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = timesMs[hi] - timesMs[lo];
    if (span <= 0) return _position(lo, 0);
    // Points are recorded as the rider moves, so a long gap between two of
    // them means the rider stopped there. They wait at the first point and
    // only set off again in time to ride the stretch at their recorded speed,
    // rather than creeping through the stop.
    final riding = _ridingMs(lo, hi);
    final leaveAt = timesMs[hi] - riding;
    if (span > riding * stopFactor + stopSlackMs && timeMs < leaveAt) {
      return _position(lo, 0);
    }
    final from = span > riding * stopFactor + stopSlackMs
        ? leaveAt
        : timesMs[lo];
    final length = timesMs[hi] - from;
    final t = length <= 0 ? 1.0 : ((timeMs - from) / length).clamp(0.0, 1.0);
    return _position(lo, t);
  }

  /// A gap longer than riding time × [stopFactor] + [stopSlackMs] holds a
  /// stop.
  static const double stopFactor = 1.5;
  static const int stopSlackMs = 3000;

  /// How long riding from point [a] to [b] took at the recorded speeds.
  int _ridingMs(int a, int b) {
    final meters = alongMeters[b] - alongMeters[a];
    final speed = speedsMps.isEmpty
        ? 4.0
        : math.max((speedsMps[a] + speedsMps[b]) / 2, 1.5);
    return (meters / speed * 1000).round();
  }

  TracePosition _position(int index, double t) {
    final next = math.min(index + 1, points.length - 1);
    final a = points[index];
    final b = points[next];
    final speed = speedsMps.isEmpty
        ? null
        : speedsMps[index] + (speedsMps[next] - speedsMps[index]) * t;
    return TracePosition(
      index: index,
      fraction: t,
      point: GeoPoint(
        latitude: a.latitude + (b.latitude - a.latitude) * t,
        longitude: a.longitude + (b.longitude - a.longitude) * t,
      ),
      alongMeters:
          alongMeters[index] + (alongMeters[next] - alongMeters[index]) * t,
      speedMps: speed,
    );
  }
}

/// A rider's place on their trace at one moment.
class TracePosition {
  const TracePosition({
    required this.index,
    required this.fraction,
    required this.point,
    required this.alongMeters,
    this.speedMps,
  });

  /// The trace point just before, and how far on towards the next (0–1).
  final int index;
  final double fraction;
  final GeoPoint point;
  final double alongMeters;
  final double? speedMps;
}

/// Where and when a rider reached their top speed.
class TopSpeedMoment {
  const TopSpeedMoment({
    required this.uid,
    required this.speedMps,
    this.point,
    this.atMs,
    this.distanceMeters,
  });

  final String uid;
  final double speedMps;
  final GeoPoint? point;
  final int? atMs;

  /// How far into the ride.
  final double? distanceMeters;
}

/// A stop of a minute or more.
class RideStop {
  const RideStop({
    required this.startMs,
    required this.durationMs,
    required this.distanceMeters,
    required this.point,
  });

  final int startMs;
  final int durationMs;

  /// How far into the ride.
  final double distanceMeters;
  final GeoPoint point;
}

enum TimelineKind { started, topSpeed, longestStop, halfway, finished }

/// One moment of the ride, in time order.
class TimelineEvent {
  const TimelineEvent({
    required this.kind,
    required this.atMs,
    required this.title,
    this.detail,
    this.distanceMeters,
  });

  final TimelineKind kind;
  final int atMs;
  final String title;

  /// A short line under the title: "68 km/h at 14.2 km".
  final String? detail;
  final double? distanceMeters;
}

/// What a [StoryInsight] is about; picks its icon.
enum StoryInsightKind {
  withGroup,
  cruising,
  fastestSection,
  smoothestSection,
  strongFinish,
  nonStop,
  consistent,
}

/// One thing worth knowing about the ride, readable in a couple of seconds: a
/// short headline and one plain line beneath it.
class StoryInsight {
  const StoryInsight({
    required this.kind,
    required this.headline,
    required this.detail,
  });

  final StoryInsightKind kind;
  final String headline;
  final String detail;
}

/// What a [GroupMoment] celebrates; picks its icon.
enum MomentKind {
  fastest,
  catchUp,
  closestPair,
  strongestFinish,
  nonStop,
  mostConsistent,
}

/// A memorable moment of a group ride.
class GroupMoment {
  const GroupMoment({
    required this.kind,
    required this.title,
    required this.headline,
    required this.detail,
    required this.riderUids,
  });

  final MomentKind kind;

  /// What it is: "Biggest catch-up".
  final String title;

  /// Who and what: "Rahul closed 420 m".
  final String headline;
  final String detail;

  /// The riders it is about, for their colour.
  final List<String> riderUids;
}

/// One row of the final leaderboard.
class FinalStanding {
  const FinalStanding({
    required this.position,
    required this.uid,
    required this.name,
    required this.colorId,
    required this.distanceMeters,
    required this.averageSpeedMps,
    required this.maxSpeedMps,
  });

  final int position;
  final String uid;
  final String name;
  final String? colorId;
  final double distanceMeters;

  /// While moving.
  final double averageSpeedMps;
  final double maxSpeedMps;
}

/// How this rider rode: the figures shown once, in one place.
class Performance {
  const Performance({
    required this.averageSpeedMps,
    required this.averageMovingSpeedMps,
    required this.moving,
    required this.idle,
  });

  /// Distance over the whole time on the ride, stops included.
  final double averageSpeedMps;

  /// Distance over the time actually moving.
  final double averageMovingSpeedMps;
  final Duration moving;
  final Duration idle;

  /// Share of the ride spent moving, 0–1.
  double get movingShare {
    final total = moving.inMilliseconds + idle.inMilliseconds;
    return total <= 0 ? 0 : moving.inMilliseconds / total;
  }
}

/// The finished ride told as a story: everything the results and history
/// screens show beyond the summary's own numbers, worked out once.
class RideStory {
  const RideStory({
    required this.isGroup,
    required this.performance,
    required this.timeline,
    required this.insights,
    required this.moments,
    required this.standings,
    required this.topSpeeds,
    required this.traces,
    required this.startMs,
    required this.endMs,
  });

  /// More than one rider covered ground.
  final bool isGroup;

  /// This rider's figures; `null` when they did not ride.
  final Performance? performance;

  /// This rider's ride, start to finish.
  final List<TimelineEvent> timeline;
  final List<StoryInsight> insights;

  /// Group rides only.
  final List<GroupMoment> moments;

  /// Best first; group rides only.
  final List<FinalStanding> standings;

  /// Every rider's top speed, by uid.
  final Map<String, TopSpeedMoment> topSpeeds;

  /// Every rider's route in time, by uid.
  final Map<String, RideTrace> traces;

  /// The span the replay covers.
  final int startMs;
  final int endMs;

  /// Whether any trace's times were worked out rather than recorded.
  bool get timesEstimated => traces.values.any((t) => t.estimated);

  /// Whether the group's ride can be replayed as it really happened: two or
  /// more riders, every one with the GPS time of each recorded point, all on
  /// one clock. Rides recorded before times were kept cannot be, and show no
  /// replay rather than an invented one.
  bool get canReplay => traces.length >= 2 && !timesEstimated;
}
