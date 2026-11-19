import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../insights/domain/story/ride_story.dart';
import '../../../ride/domain/geo_point.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../../ride/presentation/map/night_tile_layer.dart';
import '../../domain/ride_details.dart';
import '../../domain/speed_scale.dart';
import '../route/route_scene.dart';

/// Frames [points] on the map, leaving [padding] around them.
CameraFit _fitTo(Iterable<GeoPoint> points, EdgeInsets padding) {
  var south = double.infinity;
  var north = -double.infinity;
  var west = double.infinity;
  var east = -double.infinity;
  for (final p in points) {
    south = math.min(south, p.latitude);
    north = math.max(north, p.latitude);
    west = math.min(west, p.longitude);
    east = math.max(east, p.longitude);
  }
  const minSpan = 0.0008;
  if (!south.isFinite) {
    south = 0;
    north = 0;
    west = 0;
    east = 0;
  }
  if (north - south < minSpan) {
    final m = (north + south) / 2;
    south = m - minSpan / 2;
    north = m + minSpan / 2;
  }
  if (east - west < minSpan) {
    final m = (east + west) / 2;
    west = m - minSpan / 2;
    east = m + minSpan / 2;
  }
  return CameraFit.bounds(
    bounds: LatLngBounds(LatLng(south, west), LatLng(north, east)),
    padding: padding,
    maxZoom: 17,
  );
}

/// Glides a [MapController] from one view to another.
class _CameraGlide {
  _CameraGlide(this._map, TickerProvider vsync)
    : _controller = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 800),
      ) {
    _controller.addListener(_step);
  }

  final MapController _map;
  final AnimationController _controller;
  LatLng? _fromCenter;
  double? _fromZoom;
  LatLng? _toCenter;
  double? _toZoom;

  void to(LatLng center, double zoom, {Duration? duration, double from = 0}) {
    _fromCenter = _map.camera.center;
    _fromZoom = _map.camera.zoom;
    _toCenter = center;
    _toZoom = zoom;
    if (duration != null) _controller.duration = duration;
    _controller.forward(from: from);
  }

  void _step() {
    final a = _fromCenter;
    final b = _toCenter;
    final za = _fromZoom;
    final zb = _toZoom;
    if (a == null || b == null || za == null || zb == null) return;
    final t = AppMotion.move.transform(_controller.value);
    _map.move(
      LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ),
      za + (zb - za) * t,
    );
  }

  void dispose() => _controller.dispose();
}

/// Marks where a rider went fastest: a bolt in their colour with a ring that
/// grows while it is the one being shown.
class TopSpeedMarker extends StatelessWidget {
  const TopSpeedMarker({
    super.key,
    required this.color,
    required this.active,
    this.onTap,
  });

  final Color color;
  final bool active;
  final VoidCallback? onTap;

  static const double size = 30;

  @override
  Widget build(BuildContext context) {
    final marker = AnimatedScale(
      duration: AppMotion.springDuration,
      curve: AppMotion.spring,
      scale: active ? 1.15 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
          border: Border.all(color: color, width: active ? 3 : 2),
        ),
        child: Icon(Icons.bolt_rounded, size: AppIconSize.medium, color: color),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: 'Top speed',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(child: marker),
      ),
    );
  }
}

/// What happened at the top-speed point: the speed, when, and how far in.
class TopSpeedCallout extends StatelessWidget {
  const TopSpeedCallout({
    super.key,
    required this.moment,
    required this.color,
    this.name,
  });

  final TopSpeedMoment moment;
  final Color color;

  /// Whose it was, in a group ride.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = moment.atMs;
    final distance = moment.distanceMeters;
    final detail = [
      if (at != null) RideFormat.time(DateTime.fromMillisecondsSinceEpoch(at)),
      if (distance != null) '${RideFormat.distance(distance)} into the ride',
    ].join(' · ');
    return GlassPanel(
      accent: color,
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: color, size: AppIconSize.medium),
          const SizedBox(width: AppSpacing.sm),
          Text(
            RideFormat.speed(moment.speedMps),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              [?name, detail].where((s) => s.isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Group replay ------------------------------------------------------------

/// The state of a ride replay: the moment shown, whether it plays, how fast,
/// and which rider is picked.
class ReplayController extends ChangeNotifier {
  ReplayController({required this.startMs, required this.endMs, this.selected})
    : _timeMs = endMs;

  final int startMs;
  final int endMs;

  /// The whole ride plays in this long at 1×.
  static const Duration baseLength = Duration(seconds: 30);
  static const List<double> speeds = [1, 2, 4];

  int _timeMs;
  bool _playing = false;
  int _speedIndex = 0;
  String? selected;
  int _focusId = 0;

  int get timeMs => _timeMs;
  bool get playing => _playing;
  double get speed => speeds[_speedIndex];

  /// 0–1 through the ride.
  double get progress =>
      endMs <= startMs ? 1 : (_timeMs - startMs) / (endMs - startMs);

  /// Increases each time the top speed of [selected] should be shown.
  int get focusId => _focusId;

  void seek(double fraction) {
    _timeMs = (startMs + (endMs - startMs) * fraction.clamp(0.0, 1.0)).round();
    notifyListeners();
  }

  void togglePlay() {
    if (!_playing && _timeMs >= endMs) _timeMs = startMs;
    _playing = !_playing;
    notifyListeners();
  }

  void pause() {
    if (!_playing) return;
    _playing = false;
    notifyListeners();
  }

  void cycleSpeed() {
    _speedIndex = (_speedIndex + 1) % speeds.length;
    notifyListeners();
  }

  void select(String? uid) {
    if (uid == selected) return;
    selected = uid;
    notifyListeners();
  }

  /// Moves to [uid]'s top speed and shows it.
  void showTopSpeed(String uid, int? atMs) {
    selected = uid;
    _playing = false;
    if (atMs != null) _timeMs = atMs.clamp(startMs, endMs);
    _focusId++;
    notifyListeners();
  }

  /// Advances playback by [elapsed] of real time.
  void advance(Duration elapsed) {
    if (!_playing) return;
    final span = endMs - startMs;
    final step =
        span * speed * elapsed.inMicroseconds / baseLength.inMicroseconds;
    _timeMs = math.min(endMs, _timeMs + step.round());
    if (_timeMs >= endMs) _playing = false;
    notifyListeners();
  }
}

/// The group's ride, replayed on the map: every rider's trail grows in their
/// own colour as the moment moves on, with a dot where each one was. Tapping a
/// rider picks them out, with their speed, distance and place at that moment.
class ReplayMap extends StatefulWidget {
  const ReplayMap({
    super.key,
    required this.story,
    required this.routes,
    required this.colors,
    required this.names,
    required this.controller,
    this.myUid,
    this.onExpand,
    this.height = 320,
  });

  final RideStory story;
  final Map<String, RiderRoute> routes;
  final Map<String, Color> colors;
  final Map<String, String> names;
  final ReplayController controller;
  final String? myUid;
  final VoidCallback? onExpand;
  final double height;

  @override
  State<ReplayMap> createState() => _ReplayMapState();
}

class _ReplayMapState extends State<ReplayMap> with TickerProviderStateMixin {
  final MapController _map = MapController();
  late final _CameraGlide _glide = _CameraGlide(_map, this);
  late final Ticker _ticker = createTicker(_onTick);
  late RouteScene _scene;
  Duration? _lastTick;
  bool _ready = false;
  int _focusId = 0;
  MapCamera? _rest;

  /// The first showing plays the whole ride through quickly, drawing every
  /// route in.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..addListener(_onIntro);

  static const EdgeInsets _padding = EdgeInsets.all(AppSpacing.xxl);

  @override
  void initState() {
    super.initState();
    _scene = RouteScene.build(
      routes: widget.routes,
      colors: widget.colors,
      scale: SpeedScale.fromSeries(const []),
    );
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _ticker.dispose();
    _intro.dispose();
    _glide.dispose();
    _map.dispose();
    super.dispose();
  }

  /// Plays the ride through at one steady pace: every rider moves on the
  /// same clock, so gaps, stops and arrivals keep their real proportions.
  void _onIntro() => widget.controller.seek(_intro.value);

  void _onController() {
    final c = widget.controller;
    if (c.playing) {
      _intro.stop();
      if (!_ticker.isActive) {
        _lastTick = null;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
    if (c.focusId != _focusId) {
      _focusId = c.focusId;
      _intro.stop();
      final point = widget.story.topSpeeds[c.selected]?.point;
      if (point != null && _ready) {
        _glide.to(
          LatLng(point.latitude, point.longitude),
          math.max(_rest?.zoom ?? 15, 15.5),
        );
      }
    }
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last != null) widget.controller.advance(elapsed - last);
  }

  void _onReady() {
    _ready = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rest = _fitTo(
        [for (final r in widget.routes.values) ...r.points],
        _padding,
      ).fit(_map.camera);
      _rest = rest;
      if (MediaQuery.disableAnimationsOf(context)) {
        _map.move(rest.center, rest.zoom);
        return;
      }
      _map.move(rest.center, rest.zoom - 1.2);
      _glide.to(
        rest.center,
        rest.zoom,
        duration: const Duration(milliseconds: 1100),
      );
      _intro.forward(from: 0);
    });
  }

  void _onTap(TapPosition tap, LatLng _) {
    final at = tap.relative;
    final hit = at == null ? null : _scene.riderNear(at, _map.camera);
    final c = widget.controller;
    if (hit != null) AppHaptics.selection();
    c.select(hit == c.selected ? null : hit);
    final rest = _rest;
    if (hit == null && rest != null) _glide.to(rest.center, rest.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final selected = c.selected;
    final top = selected == null ? null : widget.story.topSpeeds[selected];
    final topPoint = top?.point;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCameraFit: _fitTo([
                    for (final r in widget.routes.values) ...r.points,
                  ], _padding),
                  backgroundColor: AppColors.background,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                  onMapReady: _onReady,
                  onTap: _onTap,
                ),
                children: [
                  const NightTileLayer(),
                  _ReplayLayer(
                    scene: _scene,
                    story: widget.story,
                    controller: c,
                  ),
                  if (top != null && topPoint != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(topPoint.latitude, topPoint.longitude),
                          width: TopSpeedMarker.size + 8,
                          height: TopSpeedMarker.size + 8,
                          child: TopSpeedMarker(
                            color: widget.colors[selected] ?? AppColors.primary,
                            active: c.focusId > 0,
                            onTap: () => c.showTopSpeed(selected!, top.atMs),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (widget.onExpand != null)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: AppIconButton(
                  glass: true,
                  icon: Icons.open_in_full_rounded,
                  tooltip: 'Explore the map',
                  onPressed: widget.onExpand,
                ),
              ),
            if (top != null && c.focusId > 0)
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: TopSpeedCallout(
                  moment: top,
                  color: widget.colors[selected] ?? AppColors.primary,
                  name: selected == widget.myUid
                      ? 'You'
                      : widget.names[selected],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplayLayer extends StatelessWidget {
  const _ReplayLayer({
    required this.scene,
    required this.story,
    required this.controller,
  });

  final RouteScene scene;
  final RideStory story;
  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ReplayPainter(
            scene: scene,
            story: story,
            controller: controller,
            camera: MapCamera.of(context),
          ),
        ),
      ),
    );
  }
}

class _ReplayPainter extends CustomPainter {
  _ReplayPainter({
    required this.scene,
    required this.story,
    required this.controller,
    required this.camera,
  }) : super(repaint: controller);

  final RouteScene scene;
  final RideStory story;
  final ReplayController controller;
  final MapCamera camera;

  @override
  void paint(Canvas canvas, Size size) {
    final transform = scene.transformFor(camera);
    final t = controller.timeMs;
    final selected = controller.selected;
    // The picked rider is drawn last, on top.
    final riders = [...scene.riders]
      ..sort((a, b) => (a.uid == selected ? 1 : 0) - (b.uid == selected ? 1 : 0));
    for (final rider in riders) {
      final trace = story.traces[rider.uid];
      if (trace == null || rider.length < 2) continue;
      final dimmed = selected != null && rider.uid != selected;
      // Not set off yet: only the faint path they will ride, no rider.
      final started = t >= trace.startMs;
      final position = trace.at(t);
      final full = Path();
      final ridden = Path();
      for (var i = 0; i < rider.length; i++) {
        final x = transform.mapX(rider.xs[i], rider.ys[i]);
        final y = transform.mapY(rider.xs[i], rider.ys[i]);
        if (i == 0) {
          full.moveTo(x, y);
          ridden.moveTo(x, y);
        } else {
          full.lineTo(x, y);
          if (i <= position.index) ridden.lineTo(x, y);
        }
      }
      final i = position.index;
      final j = math.min(i + 1, rider.length - 1);
      final ax = transform.mapX(rider.xs[i], rider.ys[i]);
      final ay = transform.mapY(rider.xs[i], rider.ys[i]);
      final bx = transform.mapX(rider.xs[j], rider.ys[j]);
      final by = transform.mapY(rider.xs[j], rider.ys[j]);
      final dot = Offset(
        ax + (bx - ax) * position.fraction,
        ay + (by - ay) * position.fraction,
      );
      ridden.lineTo(dot.dx, dot.dy);

      final alpha = dimmed ? 0.3 : 1.0;
      canvas.drawPath(
        full,
        _stroke(rider.color.withValues(alpha: 0.16 * alpha), 3),
      );
      if (!started) continue;
      canvas
        ..drawPath(
          ridden,
          _stroke(Colors.black.withValues(alpha: 0.5 * alpha), 7),
        )
        ..drawPath(
          ridden,
          _stroke(
            rider.color.withValues(alpha: alpha),
            rider.uid == selected ? 5 : 4,
          ),
        )
        ..drawCircle(dot, 8, Paint()..color = AppColors.background)
        ..drawCircle(dot, 6, Paint()..color = rider.color.withValues(alpha: alpha))
        ..drawCircle(
          dot,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: 0.9 * alpha),
        );
    }
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_ReplayPainter old) =>
      old.camera != camera || !identical(old.story, story);
}

/// Play, pause, speed and a scrubber for a [ReplayController], with the time
/// of the moment shown and, when a rider is picked, where they were then.
class ReplayControls extends StatelessWidget {
  const ReplayControls({
    super.key,
    required this.controller,
    required this.story,
    required this.colors,
    required this.names,
    this.myUid,
  });

  final ReplayController controller;
  final RideStory story;
  final Map<String, Color> colors;
  final Map<String, String> names;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final c = controller;
        final time = RideFormat.time(
          DateTime.fromMillisecondsSinceEpoch(c.timeMs),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _RoundButton(
                  icon: c.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: c.playing ? 'Pause' : 'Play',
                  onTap: () {
                    AppHaptics.selection();
                    c.togglePlay();
                  },
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.textPrimary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.12),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                    ),
                    child: Slider(
                      value: c.progress.clamp(0.0, 1.0),
                      onChangeStart: (_) => c.pause(),
                      onChanged: c.seek,
                      semanticFormatterCallback: (_) => time,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Replay speed ${c.speed.toStringAsFixed(0)} times',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.selection();
                      c.cycleSpeed();
                    },
                    child: Container(
                      padding: AppSpacing.pill,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${c.speed.toStringAsFixed(0)}×',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 52),
                Text(
                  time,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (story.timesEstimated)
                  Text(
                    'Timing estimated',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              alignment: Alignment.topCenter,
              child: c.selected == null
                  ? Text(
                      'Tap a rider to follow them',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    )
                  : _RiderNow(
                      uid: c.selected!,
                      story: story,
                      timeMs: c.timeMs,
                      color: colors[c.selected] ?? AppColors.textPrimary,
                      name: c.selected == myUid
                          ? 'You'
                          : names[c.selected] ?? 'Rider',
                      onTopSpeed: () => c.showTopSpeed(
                        c.selected!,
                        story.topSpeeds[c.selected]?.atMs,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            child: Icon(
              icon,
              key: ValueKey(icon),
              color: Colors.white,
              size: AppIconSize.large,
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the picked rider was at the moment shown.
class _RiderNow extends StatelessWidget {
  const _RiderNow({
    required this.uid,
    required this.story,
    required this.timeMs,
    required this.color,
    required this.name,
    required this.onTopSpeed,
  });

  final String uid;
  final RideStory story;
  final int timeMs;
  final Color color;
  final String name;
  final VoidCallback onTopSpeed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trace = story.traces[uid];
    if (trace == null) return const SizedBox.shrink();
    final here = trace.at(timeMs);
    // Their place at this moment, by distance covered so far.
    final along = {
      for (final t in story.traces.values) t.uid: t.at(timeMs).alongMeters,
    };
    final place =
        along.values.where((d) => d > here.alongMeters + 0.5).length + 1;
    final speed = here.speedMps;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          _Now(label: 'PLACE', value: '#$place'),
          _Now(
            label: 'SPEED',
            value: speed == null ? '—' : RideFormat.speed(speed),
          ),
          _Now(label: 'RIDDEN', value: RideFormat.distance(here.alongMeters)),
          if (story.topSpeeds[uid]?.point != null)
            IconButton(
              tooltip: 'Show top speed',
              visualDensity: VisualDensity.compact,
              onPressed: onTopSpeed,
              icon: Icon(Icons.bolt_rounded, color: color),
            ),
        ],
      ),
    );
  }
}

class _Now extends StatelessWidget {
  const _Now({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
