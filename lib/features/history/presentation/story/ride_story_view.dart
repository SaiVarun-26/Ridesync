import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/ride_loader.dart';
import '../../../insights/domain/recap/ride_recap.dart';
import '../../../insights/domain/story/ride_story.dart';
import '../../../insights/presentation/widgets/insight_visuals.dart';
import '../../../insights/presentation/widgets/recap_sections.dart';
import '../../../ride/domain/geo_point.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../../ride/domain/summary/ride_summary.dart';
import '../../domain/ride_details.dart';
import '../../domain/u_turn_detector.dart';
import '../route/ride_route_map.dart';
import '../widgets/ride_details_sections.dart';
import '../widgets/speed_chart.dart';
import 'flex_card.dart';
import 'mini_route.dart';
import 'story_maps.dart';

/// A finished ride, the same on the results screen and in history: one
/// scrolling page that opens on the ride's map, a large hero card with the
/// real map, the routes, the start and the finish. The overview (name, time
/// and headline figures) follows, then the statistics, insights and
/// highlights. Nothing is shown above the map.
///
/// Solo rides are about this rider's journey: the overview figures, the top
/// speed, how they rode, what stood out, and the timeline. Group rides
/// celebrate the group: the overview figures, the replay (only when every
/// rider's timing was recorded), the final standings and the moments, then
/// this rider's own part.
///
/// Every figure has one home. Distance and duration live in the overview;
/// speeds live in Performance (solo) or the standings (group); the top speed
/// lives in its own card (solo) or the standings (group); moving and idle time
/// live in Performance or Your ride. Insights and moments only say things the
/// figures do not.
///
/// The overview and route show as soon as the ride is loaded; the cards that
/// come from the recap (built once, in the background) join as it arrives.
class RideStoryView extends StatefulWidget {
  const RideStoryView({
    super.key,
    required this.details,
    required this.myUid,
    this.recap,
    this.title,
    this.completed = false,
    this.onRename,
    this.onShare,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.xxl,
    ),
    this.controller,
  });

  final RideDetails details;
  final String? myUid;
  final RideRecap? recap;

  /// Shown instead of the summary's name (a name just given, or the rider's
  /// own); a placeholder note while the host has not named the ride.
  final String? title;

  /// Marks the overview as the ride just finished.
  final bool completed;
  final VoidCallback? onRename;
  final VoidCallback? onShare;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  State<RideStoryView> createState() => _RideStoryViewState();
}

class _RideStoryViewState extends State<RideStoryView>
    with SingleTickerProviderStateMixin {
  final GlobalKey<RideRouteMapState> _mapKey = GlobalKey<RideRouteMapState>();
  ScrollController? _ownScroll;
  ScrollController get _scroll =>
      widget.controller ?? (_ownScroll ??= ScrollController());
  ReplayController? _replay;
  RideStory? _replayStory;

  /// The rider whose route is highlighted on the map, if any.
  String? _selectedUid;

  /// Whose top speed the map is showing, if any.
  String? _topSpeedShown;

  // --- The map's opening ------------------------------------------------------
  //
  // As it always has: the camera settles on the ride, the route draws, the
  // speed colours arrive, then the start, the finish and the arrows.

  static const int _introMs = 2700;
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introMs),
  );
  final List<CurvedAnimation> _curved = [];

  Animation<double> _span(int fromMs, int toMs, [Curve curve = AppMotion.curve]) {
    final animation = CurvedAnimation(
      parent: _intro,
      curve: Interval(fromMs / _introMs, toMs / _introMs, curve: curve),
    );
    _curved.add(animation);
    return animation;
  }

  late final RouteReveal _reveal = RouteReveal(
    camera: _span(100, 1100, Curves.linear),
    draw: _span(700, 1500, AppMotion.move),
    heat: _span(1500, 1900),
    startMarker: _span(1800, 2100),
    finishMarker: _span(2000, 2350),
    arrows: _span(2250, 2650),
  );

  @override
  void dispose() {
    for (final animation in _curved) {
      animation.dispose();
    }
    _intro.dispose();
    _ownScroll?.dispose();
    _replay?.dispose();
    super.dispose();
  }

  void _onMapReady() {
    // One frame so the map has painted before the route draws in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    });
  }

  /// The viewer touched the map: let the opening finish at once.
  void _skipIntro() {
    if (_intro.value < 1) {
      _intro.animateTo(1, duration: AppMotion.normal, curve: AppMotion.curve);
    }
  }

  RideSummary get _summary => widget.details.summary;
  bool get _isGroup => _summary.riders.length >= 2;

  /// Kept while the ride is the same, so the map is not rebuilt from scratch
  /// on every touch.
  RideDetails? _colorsOf;
  Map<String, Color> _colorsCache = const {};
  Map<String, Color> get _colors {
    if (!identical(_colorsOf, widget.details)) {
      _colorsOf = widget.details;
      _colorsCache = {
        for (final r in _summary.riders) r.uid: riderColorOf(r),
      };
    }
    return _colorsCache;
  }

  Map<String, String> get _names => {
    for (final r in _summary.riders) r.uid: riderNameOf(r),
  };

  RiderRideSummary? get _me {
    for (final r in _summary.riders) {
      if (r.uid == widget.myUid) return r;
    }
    return null;
  }

  ReplayController? _replayFor(RideStory story) {
    if (!story.canReplay) return null;
    if (!identical(story, _replayStory)) {
      _replay?.dispose();
      _replayStory = story;
      _replay = ReplayController(startMs: story.startMs, endMs: story.endMs);
    }
    return _replay;
  }

  /// Scrolls back to the top of the page, so the map card is in view.
  void _revealMap() {
    final scroll = _scroll;
    if (scroll.hasClients && scroll.offset > 0) {
      unawaited(
        scroll.animateTo(0, duration: AppMotion.slow, curve: AppMotion.curve),
      );
    }
  }

  /// How many fingers are on the map card right now.
  int _fingersOnMap = 0;

  void _onMapFingers(int delta) {
    final next = math.max(0, _fingersOnMap + delta);
    if ((next > 0) != (_fingersOnMap > 0)) {
      setState(() => _fingersOnMap = next);
    } else {
      _fingersOnMap = next;
    }
  }

  /// Takes the top-speed callout away and frames the whole ride again.
  void _hideTopSpeed() {
    setState(() => _topSpeedShown = null);
    _mapKey.currentState?.fitRoute();
  }

  void _select(String? uid) {
    if (uid == _selectedUid && _topSpeedShown == null) return;
    final wasShowingTopSpeed = _topSpeedShown != null;
    setState(() {
      _selectedUid = uid;
      _topSpeedShown = null;
    });
    if (wasShowingTopSpeed) _mapKey.currentState?.fitRoute();
  }

  /// Flies the map to where [uid] went fastest.
  void _showTopSpeed(String uid) {
    final point = widget.recap?.story?.topSpeeds[uid]?.point;
    if (point == null) return;
    AppHaptics.selection();
    setState(() => _topSpeedShown = uid);
    _revealMap();
    _mapKey.currentState?.showPoint(LatLng(point.latitude, point.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.recap?.story;
    final cards = _isGroup ? _groupCards(story) : _soloCards(story);
    final hasRoute = widget.details.routes.values.any(
      (r) => r.points.length >= 2,
    );
    final top = story?.topSpeeds[_topSpeedShown];

    return ListView(
      controller: _scroll,
      padding: widget.padding,
      // While a finger is on the map the map gets the gesture, so it pans,
      // zooms and turns instead of the page scrolling.
      physics: _fingersOnMap > 0
          ? const NeverScrollableScrollPhysics()
          : null,
      children: [
        // The ride's map comes first and is the largest thing on the page,
        // so the route is seen before any numbers. The same card for solo
        // and group rides; tap a route to pick that rider out.
        if (hasRoute) ...[
          LayoutBuilder(
            builder: (context, box) => _RouteMapCard(
              height: (box.maxWidth * 1.1).clamp(320.0, 460.0),
              onFingers: _onMapFingers,
              map: RideRouteMap(
                key: _mapKey,
                details: widget.details,
                colors: _colors,
                myUid: widget.myUid,
                selectedUid: _selectedUid,
                onSelect: _select,
                topInset: 0,
                bottomInset: 0,
                reveal: _reveal,
                onReady: _onMapReady,
                onInteract: _skipIntro,
                extraMarkers: _topSpeedMarkers(story),
              ),
              callout: top == null
                  ? null
                  : FadeSlideIn(
                      key: ValueKey(_topSpeedShown),
                      child: TopSpeedCallout(
                        moment: top,
                        color: _colors[_topSpeedShown] ?? AppColors.primary,
                        name: _isGroup
                            ? (_topSpeedShown == widget.myUid
                                  ? 'You'
                                  : _names[_topSpeedShown])
                            : null,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        for (final card in cards) ...[
          card,
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  /// The top-speed marker on the map: of the rider picked out, else this
  /// rider's own.
  List<Marker> _topSpeedMarkers(RideStory? story) {
    if (story == null) return const [];
    final uid = _topSpeedShown ?? _selectedUid ?? widget.myUid;
    final top = story.topSpeeds[uid];
    final point = top?.point;
    if (uid == null || point == null) return const [];
    return [
      Marker(
        point: LatLng(point.latitude, point.longitude),
        width: TopSpeedMarker.size + 8,
        height: TopSpeedMarker.size + 8,
        child: TopSpeedMarker(
          color: _colors[uid] ?? AppColors.primary,
          active: _topSpeedShown == uid,
          onTap: () =>
              _topSpeedShown == uid ? _hideTopSpeed() : _showTopSpeed(uid),
        ),
      ),
    ];
  }

  Widget _header() => _RideHeader(
    summary: _summary,
    title: widget.title,
    completed: widget.completed,
    group: _isGroup,
    onRename: widget.onRename,
  );

  // --- Solo -------------------------------------------------------------------

  List<Widget> _soloCards(RideStory? story) {
    final uid = widget.myUid ?? _summary.riders.firstOrNull?.uid;
    final route = widget.details.routes[uid];
    final me = _me ?? _summary.riders.firstOrNull;
    var i = 0;
    final overview = _OverviewCard(
      index: i++,
      header: _header(),
      summary: _summary,
      recap: widget.recap,
      distanceMeters: me?.distanceMeters ?? _summary.group.longestDistanceMeters,
    );
    final topSpeed = _topSpeedCard(story, uid, i);
    if (topSpeed != null) i++;
    return [
      overview,
      ?topSpeed,
      ..._recapCards(story, startIndex: i, route: route, group: false),
    ];
  }

  /// [uid]'s fastest moment, right under the overview: the speed, when, and a
  /// drawing of the route pointing to where; tap it to see the spot on the
  /// map.
  Widget? _topSpeedCard(RideStory? story, String? uid, int index) {
    final top = story?.topSpeeds[uid];
    if (uid == null || top == null || top.speedMps <= 0) return null;
    RiderRideSummary? rider;
    for (final r in _summary.riders) {
      if (r.uid == uid) rider = r;
    }
    return _TopSpeedCard(
      index: index,
      moment: top,
      color: rider == null ? AppColors.primary : riderColorOf(rider),
      route: widget.details.routes[uid]?.points,
      onShow: top.point == null ? null : () => _showTopSpeed(uid),
    );
  }

  // --- Group ------------------------------------------------------------------

  List<Widget> _groupCards(RideStory? story) {
    final replay = story == null ? null : _replayFor(story);
    var i = 0;
    final overview = _OverviewCard(
      index: i++,
      header: _header(),
      summary: _summary,
      recap: widget.recap,
      distanceMeters: _summary.group.totalDistanceMeters,
      group: true,
    );
    final topSpeed = _topSpeedCard(story, widget.myUid, i);
    if (topSpeed != null) i++;
    return [
      overview,
      ?topSpeed,
      // Only when every rider's timing was recorded, so the replay shows the
      // ride exactly as it happened; otherwise the map above tells it.
      if (story != null && replay != null)
        FlexCard(
          index: i++,
          label: 'ROUTE REPLAY',
          icon: Icons.play_circle_outline_rounded,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReplayMap(
                story: story,
                routes: widget.details.routes,
                colors: _colors,
                names: _names,
                controller: replay,
                myUid: widget.myUid,
              ),
              const SizedBox(height: AppSpacing.md),
              ReplayControls(
                controller: replay,
                story: story,
                colors: _colors,
                names: _names,
                myUid: widget.myUid,
              ),
            ],
          ),
        ),
      if (story != null && story.standings.isNotEmpty)
        _StandingsCard(
          index: i++,
          story: story,
          myUid: widget.myUid,
          colors: _colors,
          onSelect: (uid) {
            _select(uid == _selectedUid ? null : uid);
            replay?.select(uid);
            _revealMap();
          },
        ),
      if (story != null && story.moments.isNotEmpty)
        _MomentsCard(
          index: i++,
          moments: story.moments,
          colors: _colors,
        ),
      ..._recapCards(
        story,
        startIndex: i,
        route: widget.details.routes[widget.myUid],
        group: true,
      ),
    ];
  }

  // --- Shared, from the recap -------------------------------------------------

  List<Widget> _recapCards(
    RideStory? story, {
    required int startIndex,
    required RiderRoute? route,
    required bool group,
  }) {
    if (story == null) {
      return [if (!group) const _Preparing(label: 'Reading your ride…')];
    }
    var i = startIndex;
    final performance = story.performance;
    final me = _me ?? _summary.riders.firstOrNull;
    return [
      // The top speed has its own card near the top, in group rides too.
      if (performance != null)
        _PerformanceCard(
          index: i++,
          performance: performance,
          group: group,
          speeds: route != null && route.hasSpeeds
              ? route.smoothedSpeedsMps
              : null,
        ),
      if (story.insights.isNotEmpty)
        _InsightsCard(index: i++, insights: story.insights),
      if (story.timeline.length >= 2)
        _TimelineCard(
          index: i++,
          events: story.timeline,
          route: route?.points,
          uTurns: route == null
              ? const []
              : [
                  for (final n in UTurnDetector.find(route.points))
                    route.points[n],
                ],
          color: me == null ? AppColors.primary : riderColorOf(me),
        ),
      if (widget.onShare != null)
        _ShareCard(index: i++, onShare: widget.onShare!),
    ];
  }
}

/// The ride's map as the page's hero card: the real map with every route on
/// it, framed to fit the whole ride, with rounded corners and a lifted
/// shadow.
class _RouteMapCard extends StatelessWidget {
  const _RouteMapCard({
    required this.height,
    required this.map,
    required this.callout,
    required this.onFingers,
  });

  final double height;
  final Widget map;

  /// A finger went down (+1) or up (-1) on the map.
  final ValueChanged<int> onFingers;

  /// Shown over the top of the map (the top speed), if any.
  final Widget? callout;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    return FadeSlideIn(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          boxShadow: AppShadows.lifted,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  onPointerDown: (_) => onFingers(1),
                  onPointerUp: (_) => onFingers(-1),
                  onPointerCancel: (_) => onFingers(-1),
                  child: RepaintBoundary(child: map),
                ),
              ),
              if (callout != null)
                Positioned(
                  left: AppSpacing.md,
                  // Clear of the map's own buttons.
                  right: AppSpacing.lg + 52,
                  top: AppSpacing.md,
                  child: callout!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ride's name and time, at the top of the overview card.
class _RideHeader extends StatelessWidget {
  const _RideHeader({
    required this.summary,
    required this.title,
    required this.completed,
    required this.group,
    required this.onRename,
  });

  final RideSummary summary;
  final String? title;
  final bool completed;
  final bool group;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final started = DateTime.fromMillisecondsSinceEpoch(
      summary.group.startedAtMs,
    );
    final ended = DateTime.fromMillisecondsSinceEpoch(summary.group.endedAtMs);
    final name = title ?? summary.roomName;
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed ? Icons.check_circle_rounded : Icons.flag_rounded,
                  size: AppIconSize.small,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    [
                      if (completed)
                        'RIDE COMPLETE'
                      else
                        (group ? 'GROUP RIDE' : 'SOLO RIDE'),
                      if (completed) (group ? 'GROUP' : 'SOLO'),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.normal,
                    switchInCurve: AppMotion.curve,
                    switchOutCurve: AppMotion.exit,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topLeft,
                      children: [...previous, ?current],
                    ),
                    child: Text(
                      name,
                      key: ValueKey(name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: AppTypeScale.headline,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
                if (onRename != null)
                  Semantics(
                    button: true,
                    label: 'Rename ride',
                    excludeSemantics: true,
                    child: PressableScale(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRename,
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            Icons.edit_rounded,
                            size: AppIconSize.medium,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${RideFormat.date(ended)}  ·  '
              '${RideFormat.time(started)} – ${RideFormat.time(ended)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
    );
  }
}

// --- Cards --------------------------------------------------------------------

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.index,
    required this.header,
    required this.summary,
    required this.recap,
    required this.distanceMeters,
    this.group = false,
  });

  final int index;

  /// The ride's name and time.
  final Widget header;
  final RideSummary summary;
  final RideRecap? recap;
  final double distanceMeters;
  final bool group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievements = recap?.myAchievements ?? const [];
    final weather = recap?.weather;
    final score = recap?.score;
    final delay = storyDelay(index) + const Duration(milliseconds: 250);
    return FlexCard(
      index: index,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (score != null || weather != null) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (score != null)
                  InsightPill(
                    icon: Icons.star_rounded,
                    label: '${score.value} · ${score.label}',
                    accent: AppColors.primary,
                  ),
                if (weather != null)
                  InsightPill(
                    icon: InsightVisuals.weather(
                      weather.condition,
                      isDay: weather.isDay,
                    ),
                    label: '${weather.temperatureC.round()}° · '
                        '${weather.condition.label}',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 5,
                child: StoryStat(
                  value: distanceMeters,
                  format: distanceFigure,
                  unit: distanceUnit(distanceMeters),
                  label: group ? 'TOTAL DISTANCE' : 'DISTANCE',
                  size: 40,
                  delay: delay,
                ),
              ),
              Expanded(
                flex: 4,
                child: StoryStat(
                  value: summary.group.durationMs.toDouble(),
                  format: (ms) =>
                      durationFigure(Duration(milliseconds: ms.round())),
                  label: 'DURATION',
                  size: 26,
                  delay: delay,
                ),
              ),
              if (group)
                Expanded(
                  flex: 2,
                  child: StoryStat(
                    value: summary.group.riderCount.toDouble(),
                    format: (v) => '${v.round()}',
                    label: 'RIDERS',
                    size: 26,
                    delay: delay,
                  ),
                ),
            ],
          ),
          if (recap != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              child: Text(
                recap!.sentence,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (achievements.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (n, a) in achievements.take(3).indexed)
                  FadeScaleIn(
                    blur: false,
                    spring: true,
                    duration: AppMotion.springDuration,
                    delay: Duration(milliseconds: 120 * n),
                    child: AchievementChip(kind: a.kind),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TopSpeedCard extends StatelessWidget {
  const _TopSpeedCard({
    required this.index,
    required this.moment,
    required this.color,
    required this.route,
    required this.onShow,
  });

  final int index;
  final TopSpeedMoment moment;
  final Color color;

  /// The rider's route, drawn small with the spot marked.
  final List<GeoPoint>? route;
  final VoidCallback? onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = moment.atMs;
    final distance = moment.distanceMeters;
    final line = route;
    final point =
        moment.point ??
        (distance == null || line == null
            ? null
            : MiniRoute.pointAt(line, distance));
    final when = [
      if (at != null) RideFormat.time(DateTime.fromMillisecondsSinceEpoch(at)),
      if (distance != null && distance >= 50)
        '${RideFormat.distance(distance)} into the ride',
    ].join('  ·  ');
    final card = FlexCard(
      index: index,
      accent: color,
      label: 'TOP SPEED',
      icon: Icons.bolt_rounded,
      trailing: onShow == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Show on map',
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
                Icon(Icons.chevron_right_rounded, size: AppIconSize.small, color: color),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StoryStat(
                value: moment.speedMps,
                format: speedFigure,
                unit: 'km/h',
                label: 'FASTEST MOMENT',
                size: 40,
                color: color,
                delay: storyDelay(index) + const Duration(milliseconds: 250),
              ),
              const SizedBox(width: AppSpacing.lg),
              if (when.isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Text(
                      when,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (point != null && line != null && line.length >= 2) ...[
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: storyDelay(index) + const Duration(milliseconds: 350),
              child: MiniRoute(
                points: line,
                color: color,
                events: [
                  MiniRouteEvent(
                    point: point,
                    icon: Icons.bolt_rounded,
                    badge: '${speedFigure(moment.speedMps)} km/h',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    if (onShow == null) return card;
    return Semantics(
      button: true,
      label: 'Fastest moment, ${speedFigure(moment.speedMps)} kilometres per '
          'hour. Show it on the map',
      child: PressableScale(
        child: GestureDetector(onTap: onShow, child: card),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.index,
    required this.performance,
    required this.group,
    required this.speeds,
  });

  final int index;
  final Performance performance;

  /// In a group ride the speeds already sit in the standings, so only the
  /// time split is shown here.
  final bool group;
  final List<double>? speeds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = performance;
    final delay = storyDelay(index) + const Duration(milliseconds: 250);
    final moving = (p.movingShare * 100).round();
    return FlexCard(
      index: index,
      label: group ? 'YOUR RIDE' : 'PERFORMANCE',
      icon: Icons.speed_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!group) ...[
            Row(
              children: [
                Expanded(
                  child: StoryStat(
                    value: p.averageSpeedMps,
                    format: speedFigure,
                    unit: 'km/h',
                    label: 'AVERAGE SPEED',
                    delay: delay,
                  ),
                ),
                Expanded(
                  child: StoryStat(
                    value: p.averageMovingSpeedMps,
                    format: speedFigure,
                    unit: 'km/h',
                    label: 'AVG MOVING SPEED',
                    delay: delay,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              Expanded(
                child: StoryStat(
                  value: p.moving.inMilliseconds.toDouble(),
                  format: (ms) =>
                      durationFigure(Duration(milliseconds: ms.round())),
                  label: 'MOVING TIME',
                  delay: delay,
                ),
              ),
              Expanded(
                child: StoryStat(
                  value: p.idle.inMilliseconds.toDouble(),
                  format: (ms) =>
                      durationFigure(Duration(milliseconds: ms.round())),
                  label: 'IDLE TIME',
                  delay: delay,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SplitBar(share: p.movingShare, delay: delay),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '$moving% moving',
                style: theme.textTheme.labelMedium,
              ),
              const Spacer(),
              Text(
                '${100 - moving}% stopped',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (!group && speeds != null && speeds!.length > 3) ...[
            const SizedBox(height: AppSpacing.xl),
            const CardLabel(label: 'SPEED ACROSS THE RIDE'),
            const SizedBox(height: AppSpacing.sm),
            _DelayedChart(speeds: speeds!, delay: delay),
          ],
        ],
      ),
    );
  }
}

/// Moving against stopped, as one bar that fills once it appears.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.share, required this.delay});

  final double share;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final total = delay + const Duration(milliseconds: 900);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: share.clamp(0.0, 1.0)),
      duration: total,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppMotion.curve,
      ),
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 8,
          child: Row(
            children: [
              Expanded(
                flex: (value * 1000).round().clamp(0, 1000),
                child: const ColoredBox(color: AppColors.primary),
              ),
              Expanded(
                flex: 1000 - (value * 1000).round().clamp(0, 1000),
                child: const ColoredBox(color: AppColors.border),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DelayedChart extends StatefulWidget {
  const _DelayedChart({required this.speeds, required this.delay});

  final List<double> speeds;
  final Duration delay;

  @override
  State<_DelayedChart> createState() => _DelayedChartState();
}

class _DelayedChartState extends State<_DelayedChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SpeedChart(
    speedsMps: widget.speeds,
    progress: CurvedAnimation(parent: _controller, curve: AppMotion.move),
    height: 110,
    showLabels: false,
  );
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.index, required this.insights});

  final int index;
  final List<StoryInsight> insights;

  static IconData _icon(StoryInsightKind kind) => switch (kind) {
    StoryInsightKind.withGroup => Icons.groups_rounded,
    StoryInsightKind.cruising => Icons.speed_rounded,
    StoryInsightKind.fastestSection => Icons.local_fire_department_rounded,
    StoryInsightKind.smoothestSection => Icons.waves_rounded,
    StoryInsightKind.strongFinish => Icons.trending_up_rounded,
    StoryInsightKind.nonStop => Icons.all_inclusive_rounded,
    StoryInsightKind.consistent => Icons.straighten_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlexCard(
      index: index,
      label: 'WHAT STOOD OUT',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        children: [
          for (final (n, insight) in insights.indexed) ...[
            if (n > 0) const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: storyDelay(index) + Duration(milliseconds: 120 * n),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      _icon(insight.kind),
                      size: AppIconSize.medium,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight.headline, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          insight.detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.index,
    required this.events,
    required this.route,
    required this.uTurns,
    required this.color,
  });

  final int index;
  final List<TimelineEvent> events;

  /// This rider's route, drawn small with each event that has a place
  /// marked where it happened.
  final List<GeoPoint>? route;

  /// Where the rider turned sharply back on themselves.
  final List<GeoPoint> uTurns;
  final Color color;

  /// The events drawn on the route; the start and finish have their own
  /// markers.
  List<MiniRouteEvent> _routeEvents(List<GeoPoint> line) => [
    for (final e in events)
      if (e.distanceMeters != null &&
          e.kind != TimelineKind.started &&
          e.kind != TimelineKind.finished)
        if (MiniRoute.pointAt(line, e.distanceMeters!) case final point?)
          MiniRouteEvent(point: point, icon: _icon(e.kind)),
    for (final p in uTurns)
      MiniRouteEvent(point: p, icon: Icons.u_turn_left_rounded),
  ];

  static IconData _icon(TimelineKind kind) => switch (kind) {
    TimelineKind.started => Icons.play_arrow_rounded,
    TimelineKind.topSpeed => Icons.bolt_rounded,
    TimelineKind.longestStop => Icons.pause_rounded,
    TimelineKind.halfway => Icons.adjust_rounded,
    TimelineKind.finished => Icons.flag_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = route;
    return FlexCard(
      index: index,
      label: 'TIMELINE',
      icon: Icons.timeline_rounded,
      child: Column(
        children: [
          if (line != null && line.length >= 2) ...[
            MiniRoute(points: line, color: color, events: _routeEvents(line)),
            const SizedBox(height: AppSpacing.lg),
          ],
          for (final (n, event) in events.indexed)
            // One after another, top to bottom.
            FadeSlideIn(
              delay: storyDelay(index) + Duration(milliseconds: 150 * n),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          RideFormat.time(
                            DateTime.fromMillisecondsSinceEpoch(event.atMs),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: event.kind == TimelineKind.finished
                                  ? AppColors.primary
                                  : AppColors.surfaceRaised,
                              border: Border.all(
                                color: event.kind == TimelineKind.finished
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Icon(
                              _icon(event.kind),
                              size: AppIconSize.small,
                              color: event.kind == TimelineKind.finished
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (n < events.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                color: AppColors.border,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 4,
                          bottom: n < events.length - 1 ? AppSpacing.lg : 0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title, style: theme.textTheme.titleSmall),
                            if (event.detail != null)
                              Text(
                                event.detail!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({
    required this.index,
    required this.story,
    required this.myUid,
    required this.colors,
    required this.onSelect,
  });

  final int index;
  final RideStory story;
  final String? myUid;
  final Map<String, Color> colors;
  final ValueChanged<String?>? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final head = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textTertiary,
      letterSpacing: 1,
      fontSize: 9,
    );
    return FlexCard(
      index: index,
      label: 'FINAL STANDINGS',
      icon: Icons.emoji_events_rounded,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 36 + AppSpacing.sm),
              const Expanded(child: SizedBox()),
              SizedBox(width: 56, child: Text('DIST', textAlign: TextAlign.right, style: head)),
              SizedBox(width: 48, child: Text('AVG', textAlign: TextAlign.right, style: head)),
              SizedBox(width: 48, child: Text('TOP', textAlign: TextAlign.right, style: head)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final (n, s) in story.standings.indexed)
            FadeSlideIn(
              delay: storyDelay(index) + Duration(milliseconds: 90 * n),
              child: _StandingRow(
                standing: s,
                isMe: s.uid == myUid,
                color: colors[s.uid] ?? AppColors.textPrimary,
                onTap: onSelect == null
                    ? null
                    : () {
                        AppHaptics.selection();
                        onSelect!(s.uid);
                      },
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ranked by distance · average speed while moving · km/h',
            style: head,
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.standing,
    required this.isMe,
    required this.color,
    required this.onTap,
  });

  final FinalStanding standing;
  final bool isMe;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winner = standing.position == 1;
    final figure = AppTypography.stat(fontSize: 14);
    final row = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.07)
            : winner
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isMe
              ? Colors.white.withValues(alpha: 0.22)
              : winner
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: winner
                ? const Icon(
                    Icons.emoji_events_rounded,
                    size: AppIconSize.small,
                    color: AppColors.background,
                  )
                : Text(
                    '${standing.position}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.background,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              isMe ? 'You' : standing.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: isMe || winner ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              RideFormat.distance(standing.distanceMeters),
              textAlign: TextAlign.right,
              style: figure,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              speedFigure(standing.averageSpeedMps),
              textAlign: TextAlign.right,
              style: figure.copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              speedFigure(standing.maxSpeedMps),
              textAlign: TextAlign.right,
              style: figure,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label:
          '${winner ? 'Winner' : 'Position ${standing.position}'}, '
          '${isMe ? 'you' : standing.name}, '
          '${RideFormat.distance(standing.distanceMeters)}, '
          'average ${speedFigure(standing.averageSpeedMps)}, '
          'top ${speedFigure(standing.maxSpeedMps)} kilometres per hour',
      excludeSemantics: true,
      child: onTap == null
          ? row
          : PressableScale(
              child: GestureDetector(onTap: onTap, child: row),
            ),
    );
  }
}

class _MomentsCard extends StatelessWidget {
  const _MomentsCard({
    required this.index,
    required this.moments,
    required this.colors,
  });

  final int index;
  final List<GroupMoment> moments;
  final Map<String, Color> colors;

  static IconData _icon(MomentKind kind) => switch (kind) {
    MomentKind.fastest => Icons.bolt_rounded,
    MomentKind.catchUp => Icons.fast_forward_rounded,
    MomentKind.closestPair => Icons.people_alt_rounded,
    MomentKind.strongestFinish => Icons.sports_score_rounded,
    MomentKind.nonStop => Icons.all_inclusive_rounded,
    MomentKind.mostConsistent => Icons.straighten_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlexCard(
      index: index,
      label: 'GROUP MOMENTS',
      icon: Icons.celebration_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - AppSpacing.md) / 2;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final (n, m) in moments.indexed)
                SizedBox(
                  width: width,
                  child: FadeScaleIn(
                    blur: false,
                    spring: true,
                    duration: AppMotion.springDuration,
                    delay: storyDelay(index) + Duration(milliseconds: 110 * n),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 124),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _icon(m.kind),
                                size: AppIconSize.medium,
                                color: AppColors.primary,
                              ),
                              const Spacer(),
                              for (final uid in m.riderUids)
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(left: 3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors[uid] ?? AppColors.textPrimary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            m.title.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 1,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.headline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.index, required this.onShare});

  final int index;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlexCard(
      index: index,
      accent: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share this ride', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A RideSync card with your route and numbers, ready for any app.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Create share card',
            icon: Icons.ios_share_rounded,
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const RideLoader(size: RideLoader.inline),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
