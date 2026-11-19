import 'dart:math' as math;

import '../../../history/domain/ride_details.dart';
import '../../../history/domain/speed_scale.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../../ride/domain/summary/ride_summary.dart';
import '../analysis/rider_analytics.dart';
import '../analysis/speed_profile.dart';
import 'ride_story.dart';

/// Tells a finished ride as a [RideStory]. Pure and synchronous: it runs once,
/// in the background isolate that builds the recap, and the result is cached
/// with it.
///
/// Every insight and moment is only offered when the data really supports it:
/// a short ride, a ride recorded without times or speeds, or a solo ride
/// simply has fewer, never guessed ones. Nothing here repeats a figure the
/// summary already shows; each says something new.
abstract final class RideStoryBuilder {
  /// A stop counts from this long.
  static const Duration minStop = Duration(minutes: 1);

  /// Riders within this distance are riding together.
  static const double togetherMeters = 300;

  /// How finely time-aligned comparisons sample the ride.
  static const Duration _sample = Duration(seconds: 10);

  /// Most insights and moments shown.
  static const int maxInsights = 4;
  static const int maxMoments = 4;

  /// Below this a rider is crawling or stopped.
  static const double _crawlMps = SpeedAnalyzer.crawlSpeedMps;

  static RideStory build({
    required RideDetails details,
    required String? myUid,
    required List<RiderAnalytics> riders,
  }) {
    final summary = details.summary;
    final group = summary.group;
    final byUid = {for (final r in riders) r.uid: r};

    final traces = <String, RideTrace>{};
    details.routes.forEach((uid, route) {
      final trace = _trace(uid, route, byUid[uid]?.rider, group.startedAtMs);
      if (trace != null) traces[uid] = trace;
    });

    final topSpeeds = <String, TopSpeedMoment>{};
    for (final r in riders) {
      final moment = _topSpeed(r.rider, traces[r.uid]);
      if (moment != null) topSpeeds[r.uid] = moment;
    }

    final stops = <String, List<RideStop>>{
      for (final entry in traces.entries) entry.key: _stops(entry.value),
    };

    final riding = [
      for (final r in riders)
        if (r.rode) r,
    ];
    final isGroup = summary.riders.length >= 2;
    final me = byUid[myUid];
    final myTrace = traces[myUid];

    var startMs = group.startedAtMs;
    var endMs = group.endedAtMs;
    for (final t in traces.values) {
      startMs = math.min(startMs, t.startMs);
      endMs = math.max(endMs, t.endMs);
    }

    return RideStory(
      isGroup: isGroup,
      performance: me == null || !me.rode ? null : _performance(me, group),
      timeline: me == null
          ? const []
          : _timeline(me, group, myTrace, topSpeeds[myUid], stops[myUid]),
      insights: me == null
          ? const []
          : _insights(
              me: me,
              trace: myTrace,
              stops: stops[myUid] ?? const [],
              others: [
                for (final e in traces.entries)
                  if (e.key != myUid) e.value,
              ],
            ),
      moments: riding.length >= 2
          ? _moments(riding, traces, stops, topSpeeds, myUid)
          : const [],
      standings: isGroup ? _standings(summary, byUid) : const [],
      topSpeeds: topSpeeds,
      traces: traces,
      startMs: startMs,
      endMs: math.max(endMs, startMs + 1),
    );
  }

  // --- Traces ---------------------------------------------------------------

  /// [route] in time. Recorded times are used as they are (kept from going
  /// backwards); a ride recorded before times were kept gets times worked out
  /// from its speeds and fitted to the rider's moving time.
  static RideTrace? _trace(
    String uid,
    RiderRoute route,
    RiderRideSummary? rider,
    int fallbackStartMs,
  ) {
    final points = route.points;
    final n = points.length;
    if (n < 2) return null;
    final along = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      along[i] = along[i - 1] + points[i - 1].distanceMetersTo(points[i]);
    }
    final speeds = route.hasSpeeds ? route.speedsMps : const <double>[];

    if (route.hasTimes) {
      final times = List<int>.of(route.timesMs);
      for (var i = 1; i < n; i++) {
        if (times[i] < times[i - 1]) times[i] = times[i - 1];
      }
      return RideTrace(
        uid: uid,
        points: points,
        timesMs: times,
        alongMeters: along,
        speedsMps: speeds,
        estimated: false,
      );
    }

    final fallbackSpeed = math.max(rider?.averageSpeedMps ?? 0, 2.0);
    final dt = List<double>.filled(n, 0);
    var total = 0.0;
    for (var i = 1; i < n; i++) {
      final v = speeds.isEmpty
          ? fallbackSpeed
          : math.max((speeds[i - 1] + speeds[i]) / 2, 2.0);
      dt[i] = (along[i] - along[i - 1]) / v;
      total += dt[i];
    }
    final moving = rider?.movingTimeMs ?? 0;
    final scale = total <= 0 || moving <= 0 ? 1.0 : moving / 1000 / total;
    final start = rider?.startedAtMs ?? fallbackStartMs;
    final times = List<int>.filled(n, start);
    var elapsed = 0.0;
    for (var i = 1; i < n; i++) {
      elapsed += dt[i] * scale;
      times[i] = start + (elapsed * 1000).round();
    }
    return RideTrace(
      uid: uid,
      points: points,
      timesMs: times,
      alongMeters: along,
      speedsMps: speeds,
      estimated: true,
    );
  }

  /// Where and when [rider] went fastest: as recorded during the ride when it
  /// was, else from the fastest recorded point of their route.
  static TopSpeedMoment? _topSpeed(RiderRideSummary rider, RideTrace? trace) {
    if (rider.maxSpeedMps <= 0) return null;
    var point = rider.topSpeedPoint;
    var distance = rider.topSpeedDistanceMeters;
    var at = rider.topSpeedAtMs;
    if (trace != null && trace.speedsMps.isNotEmpty) {
      var best = 0;
      for (var i = 1; i < trace.speedsMps.length; i++) {
        if (trace.speedsMps[i] > trace.speedsMps[best]) best = i;
      }
      point ??= trace.points[best];
      distance ??= trace.alongMeters[best];
      if (at == null && !trace.estimated) at = trace.timesMs[best];
    }
    return TopSpeedMoment(
      uid: rider.uid,
      speedMps: rider.maxSpeedMps,
      point: point,
      atMs: at,
      distanceMeters: distance,
    );
  }

  /// Every stop of [minStop] or longer: time between two points beyond what
  /// riding between them took. Only from recorded times.
  static List<RideStop> _stops(RideTrace trace) {
    if (trace.estimated) return const [];
    final result = <RideStop>[];
    final t = trace.timesMs;
    for (var i = 1; i < t.length; i++) {
      final meters = trace.alongMeters[i] - trace.alongMeters[i - 1];
      final v = trace.speedsMps.isEmpty
          ? 4.0
          : math.max((trace.speedsMps[i - 1] + trace.speedsMps[i]) / 2, 2.0);
      final riding = meters / v * 1000;
      final stopped = (t[i] - t[i - 1] - riding).round();
      if (stopped >= minStop.inMilliseconds) {
        result.add(
          RideStop(
            startMs: t[i - 1],
            durationMs: stopped,
            distanceMeters: trace.alongMeters[i - 1],
            point: trace.points[i - 1],
          ),
        );
      }
    }
    return result;
  }

  /// The longest distance ridden between two stops (or the whole ride).
  static double _longestNonStop(RideTrace trace, List<RideStop> stops) {
    var from = 0.0;
    var best = 0.0;
    for (final stop in stops) {
      best = math.max(best, stop.distanceMeters - from);
      from = stop.distanceMeters;
    }
    return math.max(best, trace.lengthMeters - from);
  }

  // --- This rider -------------------------------------------------------------

  static Performance _performance(RiderAnalytics me, GroupRideSummary group) {
    final elapsed = me.elapsed.inMilliseconds > 0
        ? me.elapsed
        : group.duration;
    final moving = me.rider.movingTime;
    final idle = Duration(
      milliseconds: math.max(0, elapsed.inMilliseconds - moving.inMilliseconds),
    );
    final seconds = elapsed.inMilliseconds / 1000;
    return Performance(
      averageSpeedMps: seconds <= 0 ? 0 : me.rider.distanceMeters / seconds,
      averageMovingSpeedMps: me.rider.averageSpeedMps,
      moving: moving,
      idle: idle,
    );
  }

  static List<TimelineEvent> _timeline(
    RiderAnalytics me,
    GroupRideSummary group,
    RideTrace? trace,
    TopSpeedMoment? top,
    List<RideStop>? stops,
  ) {
    final start = me.rider.startedAtMs ?? trace?.startMs ?? group.startedAtMs;
    final end = me.rider.endedAtMs ?? group.endedAtMs;
    final events = <TimelineEvent>[
      TimelineEvent(kind: TimelineKind.started, atMs: start, title: 'Started'),
    ];
    final topAt = top?.atMs;
    if (top != null && topAt != null && topAt > start && topAt < end) {
      events.add(
        TimelineEvent(
          kind: TimelineKind.topSpeed,
          atMs: topAt,
          title: 'Reached top speed',
          detail: (top.distanceMeters ?? 0) < 50
              ? null
              : 'At ${RideFormat.distance(top.distanceMeters!)}',
          distanceMeters: top.distanceMeters,
        ),
      );
    }
    final longest = stops == null || stops.isEmpty
        ? null
        : stops.reduce((a, b) => b.durationMs > a.durationMs ? b : a);
    if (longest != null && longest.startMs > start && longest.startMs < end) {
      events.add(
        TimelineEvent(
          kind: TimelineKind.longestStop,
          atMs: longest.startMs,
          title: 'Longest stop',
          detail:
              '${_minutes(longest.durationMs)} · '
              'at ${RideFormat.distance(longest.distanceMeters)}',
          distanceMeters: longest.distanceMeters,
        ),
      );
    }
    if (trace != null && !trace.estimated && trace.lengthMeters >= 1000) {
      final half = trace.lengthMeters / 2;
      for (var i = 1; i < trace.alongMeters.length; i++) {
        if (trace.alongMeters[i] < half) continue;
        final a = trace.alongMeters[i - 1];
        final b = trace.alongMeters[i];
        final f = b > a ? (half - a) / (b - a) : 0.0;
        final at =
            trace.timesMs[i - 1] +
            ((trace.timesMs[i] - trace.timesMs[i - 1]) * f).round();
        if (at > start && at < end) {
          events.add(
            TimelineEvent(
              kind: TimelineKind.halfway,
              atMs: at,
              title: 'Reached halfway',
              detail: RideFormat.distance(half),
              distanceMeters: half,
            ),
          );
        }
        break;
      }
    }
    events
      ..sort((a, b) => a.atMs.compareTo(b.atMs))
      ..add(
        TimelineEvent(
          kind: TimelineKind.finished,
          atMs: math.max(end, events.last.atMs),
          title: 'Finished',
        ),
      );
    return events;
  }

  static List<StoryInsight> _insights({
    required RiderAnalytics me,
    required RideTrace? trace,
    required List<RideStop> stops,
    required List<RideTrace> others,
  }) {
    final insights = <StoryInsight>[];
    final profile = me.speed;

    // With the group.
    if (trace != null && others.isNotEmpty) {
      final share = _togetherShare(trace, others);
      if (share != null) {
        final percent = (share * 100).round();
        insights.add(
          StoryInsight(
            kind: StoryInsightKind.withGroup,
            headline: percent >= 99
                ? 'With the group the whole way'
                : 'With the group $percent% of the ride',
            detail: 'Within ${RideFormat.distance(togetherMeters)} of '
                'another rider',
          ),
        );
      }
    }

    final speeds = trace == null || trace.speedsMps.isEmpty
        ? null
        : SpeedScale.smooth(trace.speedsMps, radius: 2);

    // Cruising speed: the 5 km/h band held for the most distance.
    if (trace != null && speeds != null) {
      final cruise = _cruisingBand(trace.alongMeters, speeds);
      if (cruise != null) {
        insights.add(
          StoryInsight(
            kind: StoryInsightKind.cruising,
            headline: 'Cruised at ${cruise.$1}–${cruise.$1 + 5} km/h',
            detail:
                'Your most-held pace, ${(cruise.$2 * 100).round()}% of the '
                'distance',
          ),
        );
      }
    }

    final fastest = profile?.fastest;
    if (fastest != null) {
      insights.add(
        StoryInsight(
          kind: StoryInsightKind.fastestSection,
          headline: 'Fastest stretch: ${_section(fastest.startMeters, fastest.endMeters)}',
          detail: 'Averaging ${RideFormat.speed(fastest.averageSpeedMps)}',
        ),
      );
    }

    if (trace != null && speeds != null) {
      final smooth = _smoothestSection(trace.alongMeters, speeds);
      if (smooth != null) {
        insights.add(
          StoryInsight(
            kind: StoryInsightKind.smoothestSection,
            headline: 'Smoothest riding: ${_section(smooth.$1, smooth.$2)}',
            detail: 'Held a steady ${RideFormat.speed(smooth.$3)}',
          ),
        );
      }
      final finish = _finishGain(trace.alongMeters, speeds);
      if (finish != null && finish >= 0.08) {
        insights.add(
          StoryInsight(
            kind: StoryInsightKind.strongFinish,
            headline: 'Strong finish',
            detail:
                'Your last stretch was ${(finish * 100).round()}% quicker '
                'than your average',
          ),
        );
      }
    }

    if (trace != null && !trace.estimated && trace.lengthMeters >= 2000) {
      if (stops.isEmpty) {
        insights.add(
          const StoryInsight(
            kind: StoryInsightKind.nonStop,
            headline: 'Not a single stop',
            detail: 'You rode the whole way without stopping',
          ),
        );
      } else {
        final run = _longestNonStop(trace, stops);
        if (run >= 2000) {
          insights.add(
            StoryInsight(
              kind: StoryInsightKind.nonStop,
              headline: '${RideFormat.distance(run)} without stopping',
              detail: 'Your longest uninterrupted stretch',
            ),
          );
        }
      }
    }

    if (profile != null && profile.consistency >= 75) {
      insights.add(
        const StoryInsight(
          kind: StoryInsightKind.consistent,
          headline: 'A very steady pace',
          detail: 'Your speed barely wavered',
        ),
      );
    }
    return insights.take(maxInsights).toList();
  }

  /// Share of [mine]'s time within [togetherMeters] of another rider, over the
  /// moments someone else was riding too; `null` with too little overlap.
  static double? _togetherShare(RideTrace mine, List<RideTrace> others) {
    var counted = 0;
    var together = 0;
    for (
      var t = mine.startMs;
      t <= mine.endMs;
      t += _sample.inMilliseconds
    ) {
      final here = mine.at(t).point;
      var any = false;
      var close = false;
      for (final other in others) {
        if (t < other.startMs || t > other.endMs) continue;
        any = true;
        if (other.at(t).point.distanceMetersTo(here) <= togetherMeters) {
          close = true;
          break;
        }
      }
      if (!any) continue;
      counted++;
      if (close) together++;
    }
    if (counted < 6) return null;
    return together / counted;
  }

  /// The 5 km/h band (its lower bound in km/h) held for the most moving
  /// distance, and its share; `null` when no band stands out.
  static (int, double)? _cruisingBand(List<double> along, List<double> speeds) {
    final bands = <int, double>{};
    var moving = 0.0;
    for (var i = 1; i < along.length; i++) {
      final v = (speeds[i - 1] + speeds[i]) / 2;
      if (v < _crawlMps) continue;
      final length = along[i] - along[i - 1];
      final band = ((v * 3.6) ~/ 5) * 5;
      bands[band] = (bands[band] ?? 0) + length;
      moving += length;
    }
    if (moving < 1000 || bands.isEmpty) return null;
    final best = bands.entries.reduce((a, b) => b.value > a.value ? b : a);
    final share = best.value / moving;
    return share >= 0.25 ? (best.key, share) : null;
  }

  /// The steadiest stretch (start, end, average speed): all moving, at a
  /// real pace, with the least variation in speed.
  static (double, double, double)? _smoothestSection(
    List<double> along,
    List<double> speeds,
  ) {
    final total = along.last;
    if (total < 2000) return null;
    final window = (total * 0.15).clamp(500.0, 2000.0);
    (double, double, double)? best;
    var bestCv = double.infinity;
    var start = 0;
    for (var end = 1; end < along.length; end++) {
      while (along[end] - along[start] > window && start < end - 1) {
        start++;
      }
      if (along[end] - along[start] < window * 0.9) continue;
      var sum = 0.0;
      var squares = 0.0;
      var length = 0.0;
      var crawling = false;
      for (var i = start + 1; i <= end; i++) {
        final v = (speeds[i - 1] + speeds[i]) / 2;
        if (v < _crawlMps) {
          crawling = true;
          break;
        }
        final d = along[i] - along[i - 1];
        sum += v * d;
        squares += v * v * d;
        length += d;
      }
      if (crawling || length <= 0) continue;
      final mean = sum / length;
      if (mean < 3) continue;
      final cv = math.sqrt(math.max(0, squares / length - mean * mean)) / mean;
      if (cv < bestCv) {
        bestCv = cv;
        best = (along[start], along[end], mean);
      }
    }
    return bestCv <= 0.12 ? best : null;
  }

  /// How much quicker the last 15% of the ride was than the whole moving
  /// average, as a share (0.12 for 12% quicker); `null` for short rides.
  static double? _finishGain(List<double> along, List<double> speeds) {
    final total = along.last;
    if (total < 2000) return null;
    final from = total * 0.85;
    double average(double fromMeters) {
      var sum = 0.0;
      var length = 0.0;
      for (var i = 1; i < along.length; i++) {
        if (along[i] <= fromMeters) continue;
        final v = (speeds[i - 1] + speeds[i]) / 2;
        if (v < _crawlMps) continue;
        final d = along[i] - math.max(along[i - 1], fromMeters);
        sum += v * d;
        length += d;
      }
      return length <= 0 ? 0 : sum / length;
    }

    final overall = average(0);
    final last = average(from);
    if (overall <= 0 || last <= 0) return null;
    return last / overall - 1;
  }

  // --- The group --------------------------------------------------------------

  static List<GroupMoment> _moments(
    List<RiderAnalytics> riding,
    Map<String, RideTrace> traces,
    Map<String, List<RideStop>> stops,
    Map<String, TopSpeedMoment> topSpeeds,
    String? myUid,
  ) {
    // This rider is 'You'; every phrase below reads right either way.
    String name(String uid) => uid == myUid
        ? 'You'
        : riding.firstWhere((r) => r.uid == uid, orElse: () => riding.first).name;
    final moments = <GroupMoment>[];

    // Fastest: who and where, the figure itself is on the leaderboard.
    final fastest = topSpeeds.values
        .where((t) => riding.any((r) => r.uid == t.uid))
        .fold<TopSpeedMoment?>(
          null,
          (best, t) => best == null || t.speedMps > best.speedMps ? t : best,
        );
    if (fastest != null) {
      final distance = fastest.distanceMeters;
      final where = [
        'Top speed of the day',
        if (distance != null && distance >= 50)
          'at ${RideFormat.distance(distance)}',
        if (fastest.atMs != null)
          RideFormat.time(DateTime.fromMillisecondsSinceEpoch(fastest.atMs!)),
      ].join(' · ');
      moments.add(
        GroupMoment(
          kind: MomentKind.fastest,
          title: 'Fastest moment',
          headline: name(fastest.uid),
          detail: where,
          riderUids: [fastest.uid],
        ),
      );
    }

    final riderTraces = [
      for (final r in riding)
        if (traces[r.uid] != null) traces[r.uid]!,
    ];
    if (riderTraces.length >= 2) {
      final catchUp = _biggestCatchUp(riderTraces);
      if (catchUp != null) {
        moments.add(
          GroupMoment(
            kind: MomentKind.catchUp,
            title: 'Biggest catch-up',
            headline:
                '${name(catchUp.$1)} closed ${RideFormat.distance(catchUp.$2)}',
            detail: 'On the leader, in ${_minutes(catchUp.$3)}',
            riderUids: [catchUp.$1],
          ),
        );
      }
      final pair = _closestPair(riderTraces);
      if (pair != null) {
        moments.add(
          GroupMoment(
            kind: MomentKind.closestPair,
            title: 'Riding partners',
            headline: '${name(pair.$1)} & ${name(pair.$2)}',
            detail: 'Usually ${RideFormat.distance(pair.$3)} apart',
            riderUids: [pair.$1, pair.$2],
          ),
        );
      }
    }

    // Strongest finish: best average over the last kilometre.
    (String, double)? finish;
    for (final t in riderTraces) {
      if (t.speedsMps.isEmpty || t.lengthMeters < 1500) continue;
      final speeds = SpeedScale.smooth(t.speedsMps, radius: 2);
      final from = t.lengthMeters - 1000;
      var sum = 0.0;
      var length = 0.0;
      for (var i = 1; i < t.alongMeters.length; i++) {
        if (t.alongMeters[i] <= from) continue;
        final d = t.alongMeters[i] - math.max(t.alongMeters[i - 1], from);
        sum += (speeds[i - 1] + speeds[i]) / 2 * d;
        length += d;
      }
      final average = length <= 0 ? 0.0 : sum / length;
      if (finish == null || average > finish.$2) finish = (t.uid, average);
    }
    if (finish != null && finish.$2 >= _crawlMps) {
      moments.add(
        GroupMoment(
          kind: MomentKind.strongestFinish,
          title: 'Strongest finish',
          headline: name(finish.$1),
          detail: 'Last kilometre at ${RideFormat.speed(finish.$2)}',
          riderUids: [finish.$1],
        ),
      );
    }

    // Longest non-stop stretch by anyone.
    (String, double)? run;
    for (final r in riding) {
      final t = traces[r.uid];
      final meters = t != null && !t.estimated
          ? _longestNonStop(t, stops[r.uid] ?? const [])
          : r.speed?.longestContinuousMeters ?? 0;
      if (run == null || meters > run.$2) run = (r.uid, meters);
    }
    if (run != null && run.$2 >= 2000) {
      moments.add(
        GroupMoment(
          kind: MomentKind.nonStop,
          title: 'Longest non-stop',
          headline: '${name(run.$1)} rode ${RideFormat.distance(run.$2)}',
          detail: 'Without a single stop',
          riderUids: [run.$1],
        ),
      );
    }

    final steady = [
      for (final r in riding)
        if (r.consistency != null) r,
    ];
    if (steady.length >= 2) {
      final best = steady.reduce(
        (a, b) => b.consistency! > a.consistency! ? b : a,
      );
      if (best.consistency! >= 60) {
        moments.add(
          GroupMoment(
            kind: MomentKind.mostConsistent,
            title: 'Most consistent',
            headline: best.name,
            detail: 'The steadiest pace of the group',
            riderUids: [best.uid],
          ),
        );
      }
    }
    return moments.take(maxMoments).toList();
  }

  /// The rider who won back the most ground on whoever was furthest along:
  /// (uid, metres regained, over how long in ms). `null` below 150 m.
  static (String, double, int)? _biggestCatchUp(List<RideTrace> traces) {
    final start = traces.map((t) => t.startMs).reduce(math.max);
    final end = traces.map((t) => t.endMs).reduce(math.min);
    if (end - start < _sample.inMilliseconds * 6) return null;
    final peak = <String, (double, int)>{};
    (String, double, int)? best;
    for (var t = start; t <= end; t += _sample.inMilliseconds) {
      final along = {for (final tr in traces) tr.uid: tr.at(t).alongMeters};
      final lead = along.values.reduce(math.max);
      for (final entry in along.entries) {
        final deficit = lead - entry.value;
        final top = peak[entry.key];
        if (top == null || deficit > top.$1) {
          peak[entry.key] = (deficit, t);
          continue;
        }
        final gained = top.$1 - deficit;
        if (best == null || gained > best.$2) {
          best = (entry.key, gained, t - top.$2);
        }
      }
    }
    return best != null && best.$2 >= 150 ? best : null;
  }

  /// The pair who usually rode closest: (uid, uid, typical gap in metres).
  static (String, String, double)? _closestPair(List<RideTrace> traces) {
    (String, String, double)? best;
    for (var i = 0; i < traces.length; i++) {
      for (var j = i + 1; j < traces.length; j++) {
        final a = traces[i];
        final b = traces[j];
        final start = math.max(a.startMs, b.startMs);
        final end = math.min(a.endMs, b.endMs);
        final gaps = <double>[
          for (var t = start; t <= end; t += _sample.inMilliseconds)
            a.at(t).point.distanceMetersTo(b.at(t).point),
        ];
        if (gaps.length < 10) continue;
        gaps.sort();
        final median = gaps[gaps.length ~/ 2];
        if (best == null || median < best.$3) best = (a.uid, b.uid, median);
      }
    }
    return best != null && best.$3 <= 500 ? best : null;
  }

  static List<FinalStanding> _standings(
    RideSummary summary,
    Map<String, RiderAnalytics> byUid,
  ) {
    final ranked = RideRankings.rank(summary.riders, RankMetric.distance);
    return [
      for (final (i, r) in ranked.indexed)
        FinalStanding(
          position: i + 1,
          uid: r.uid,
          name: byUid[r.uid]?.name ?? r.displayName ?? 'Rider',
          colorId: r.colorId,
          distanceMeters: r.distanceMeters,
          averageSpeedMps: r.averageSpeedMps,
          maxSpeedMps: r.maxSpeedMps,
        ),
    ];
  }

  // --- Words ------------------------------------------------------------------

  static String _section(double from, double to) =>
      'km ${(from / 1000).toStringAsFixed(1)}–${(to / 1000).toStringAsFixed(1)}';

  static String _minutes(int ms) {
    final minutes = (ms / 60000).round();
    if (minutes < 1) return 'under a minute';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}
