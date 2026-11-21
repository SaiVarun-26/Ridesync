import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/feedback/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/ride_loader.dart';
import '../../../core/theme/rider_palette.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../fuel/presentation/fuel_layer_preference.dart';
import '../../fuel/presentation/fuel_providers.dart';
import '../../fuel/presentation/fuel_toggle_button.dart';
import '../../fuel/presentation/fuel_station_controller.dart';
import '../../fuel/presentation/fuel_station_layer.dart';
import '../../fuel/presentation/fuel_station_sheet.dart';
import '../../room/domain/room.dart';
import '../../room/domain/room_status.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../../room/presentation/room_flow.dart';
import '../../room/presentation/widgets/room_exit_scope.dart';
import '../domain/completion/ride_end_stage.dart';
import '../domain/guidance/route_progress.dart';
import '../domain/live/ride_format.dart';
import '../domain/safety/ride_signal.dart';
import 'guidance/guidance_controller.dart';
import 'map/guided_route_layer.dart';
import 'map/live_map_commands.dart';
import 'map/marker_interpolator.dart';
import 'map/osm_map_widget.dart';
import 'map/trail_layer.dart';
import 'providers/guidance_providers.dart';
import 'providers/ride_completion_providers.dart';
import 'providers/ride_map_providers.dart';
import 'ride_map_controller.dart';
import 'safety/safety_controller.dart';
import 'auto_end/auto_end_controller.dart';
import 'auto_end/auto_end_sheet.dart';
import 'widgets/ride_action_buttons.dart';
import 'widgets/ride_complete_overlay.dart';
import 'widgets/guidance/guidance_cards.dart';
import 'widgets/guidance/route_progress_strip.dart';
import 'widgets/leaderboard/live_leaderboard.dart';
import 'widgets/leaderboard/ride_event_banner.dart';
import 'widgets/ride_control_panel.dart';
import 'widgets/ride_ending_overlay.dart';
import 'widgets/ride_map_overlays.dart';
import 'widgets/rider_info_card.dart';
import 'widgets/safety/safety_sheet.dart';
import 'widgets/safety/safety_widgets.dart';

/// The live map for room [roomCode]: Free Roam, or a Guided Ride when
/// [guided].
///
/// Every rider appears as a dot in their color with a fading trail;
/// positions sync in real time and the camera follows this rider. A guided
/// ride adds the planned route, turn guidance, off-route help and route
/// progress. All ride logic lives in [RideMapController], guidance in
/// [GuidanceController] and safety signals in [SafetyController]; this
/// screen only lays out the map and its overlays.
class RideMapScreen extends ConsumerStatefulWidget {
  const RideMapScreen({super.key, required this.roomCode, this.guided = false});

  final String roomCode;

  /// Whether this is a guided ride with a planned route.
  final bool guided;

  @override
  ConsumerState<RideMapScreen> createState() => _RideMapScreenState();
}

class _RideMapScreenState extends ConsumerState<RideMapScreen> {
  String get roomCode => widget.roomCode;

  /// How long the completion scene plays before the results open by
  /// themselves: long enough to see the figures land and to read them.
  static const Duration _completeHold = Duration(milliseconds: 4200);

  Future<void>? _hold;

  /// Completed when the rider asks for the results before the hold is over.
  final Completer<void> _skipHold = Completer<void>();

  /// Completed once this rider's ended ride is saved.
  final Completer<void> _saved = Completer<void>();

  final GlobalKey _panelKey = GlobalKey();

  /// How much of the map's bottom the ride panel covers, in pixels.
  final ValueNotifier<double> _panelInset = ValueNotifier<double>(0);

  /// Space kept between the panel and the rider.
  static const double _panelClearance = 8;

  /// Steers the map camera: recenter, route overview, focus on a rider.
  final LiveMapCommands _commands = LiveMapCommands();

  bool _introPlayed = false;
  Timer? _introTimer;

  /// The turn whose approach was last marked with a haptic.
  double? _cuedTurnAlong;

  /// Signals already announced with a haptic, as "uid:sentAt".
  final Set<String> _announcedSignals = {};

  /// How long the route overview shows when a guided ride opens.
  static const Duration _introDelay = Duration(milliseconds: 600);
  static const Duration _introHold = Duration(milliseconds: 2800);

  /// A rider further along than this has resumed the ride: no intro.
  static const double _introMaxProgressMeters = 300;

  /// The approach to a turn is marked this far before it.
  static const double _turnCueMeters = 120;

  /// The rider's marker snaps onto the route within this distance of it.
  static const double _snapMeters = 12;

  late final FuelStationController _fuel = ref.read(
    fuelStationControllerProvider,
  );

  /// Fuel notices already shown on this ride, so each shows once.
  final Set<FuelSearchState> _fuelNoticesShown = {};

  @override
  void initState() {
    super.initState();
    // The ride has started for this rider: the live map is opening.
    AppHaptics.milestone();
    _fuel.addListener(_onFuelChanged);
  }

  /// Says once, quietly, when there is no fuel nearby or it cannot be
  /// looked up, instead of leaving the map silently without stations.
  void _onFuelChanged() {
    final state = _fuel.state;
    final message = switch (state) {
      FuelSearchState.noneNearby =>
        'No fuel stations within '
            '${(_fuel.radiusMeters / 1000).round()} km.',
      FuelSearchState.unavailable =>
        'Fuel stations are unavailable right now. Retrying.',
      _ => null,
    };
    // Nothing to say about a layer the rider has hidden.
    if (ref.read(fuelLayerVisibleProvider) != true) return;
    if (message == null || !_fuelNoticesShown.add(state)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.local_gas_station_rounded,
                  size: AppIconSize.medium,
                  color: FuelStationLayer.color,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
    });
  }

  @override
  void dispose() {
    _fuel.removeListener(_onFuelChanged);
    _introTimer?.cancel();
    _commands.dispose();
    _panelInset.dispose();
    super.dispose();
  }

  /// A guided ride opens on the whole route, then glides down to the rider.
  void _playIntro(GuidanceState guidance) {
    _introPlayed = true;
    final guide = guidance.guide;
    final snapshot = guidance.snapshot;
    if (guide == null ||
        snapshot == null ||
        snapshot.alongMeters > _introMaxProgressMeters) {
      return;
    }
    _introTimer = Timer(_introDelay, () {
      if (!mounted) return;
      _commands.showOverview(guide.geometry.points);
      _introTimer = Timer(_introHold, () {
        if (mounted) _commands.recenter();
      });
    });
  }

  void _onGuidanceChanged(GuidanceState? previous, GuidanceState next) {
    if (!_introPlayed && next.guide != null && next.snapshot != null) {
      _playIntro(next);
    }
    final was = previous?.snapshot;
    final now = next.snapshot;
    if (now == null) return;
    if (!(was?.hasArrived ?? false) && now.hasArrived) {
      AppHaptics.milestone();
      return;
    }
    if (!(previous?.isOffRoute ?? false) && next.isOffRoute) {
      AppHaptics.error();
    } else if ((previous?.isOffRoute ?? false) && !next.isOffRoute) {
      AppHaptics.success();
    }
    final turn = now.next;
    final toTurn = now.metersToNext;
    if (turn != null &&
        toTurn != null &&
        toTurn <= _turnCueMeters &&
        !next.isOffRoute &&
        _cuedTurnAlong != turn.alongMeters) {
      _cuedTurnAlong = turn.alongMeters;
      AppHaptics.light();
    }
  }

  void _onSafetyChanged(SafetyState? previous, SafetyState next) {
    for (final signal in next.alerts) {
      if (!_announcedSignals.add('${signal.uid}:${signal.sentAtMs}')) continue;
      if (signal.kind == RideSignalKind.attention) {
        AppHaptics.error();
      } else {
        AppHaptics.light();
      }
    }
  }

  void _measurePanel() {
    final box = _panelKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final screen = MediaQuery.sizeOf(context).height;
    _panelInset.value = math.max(0, screen - top + _panelClearance);
  }

  /// Waits a beat once the ride has ended. Returns the same future for
  /// repeated calls while it runs.
  Future<void> _holdBeforeResults(Room room) {
    final uid = ref.read(authStateChangesProvider).value?.uid;
    final mine = uid == null ? null : room.memberByUid(uid);
    final over =
        room.status == RoomStatus.ended || (mine?.hasFinished ?? false);
    if (!over) return Future<void>.value();
    return _hold ??= _finishSequence();
  }

  /// What happens once this rider's ride is over, however it ended (End Ride,
  /// the auto-end countdown, or the room closing): the completion scene plays
  /// (with its own haptic) until the hold runs out or the rider skips it, then
  /// the results open. The ride is named there, the same way every time.
  Future<void> _finishSequence() async {
    // A ride this rider ended is shown complete only once it is saved.
    final end = ref.read(rideEndControllerProvider(roomCode));
    if (end.isEnding && !end.completed) await _saved.future;
    if (!mounted) return;
    _frameFinishedRide();
    await Future.any<void>([
      Future<void>.delayed(_completeHold),
      _skipHold.future,
    ]);
  }

  /// Asks before ending this rider's ride. Everyone else carries on.
  Future<void> _confirmEnd(bool isGroupRide) async {
    final end = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: 'End your ride?',
        message: isGroupRide
            ? 'This will finish your ride and save it to your history. '
                  'Everyone else keeps riding.'
            : 'This will finish your ride and save it to your history.',
        cancelLabel: 'Cancel',
        confirmLabel: 'End Ride',
        destructive: true,
      ),
    );
    if (end != true || !mounted) return;
    unawaited(ref.read(rideEndControllerProvider(roomCode).notifier).endRide());
  }

  void _openResults() {
    if (!_skipHold.isCompleted) _skipHold.complete();
  }

  /// Eases the camera out to show the whole ride, once it has ended.
  void _frameFinishedRide() {
    final trail = ref
        .read(rideMapControllerProvider(roomCode))
        .trails[ref.read(authStateChangesProvider).value?.uid];
    final points = trail?.points;
    if (points == null || points.length < 2) return;
    var from = 0;
    for (var i = points.length - 1; i > 0; i--) {
      if (points[i].startsSegment) {
        from = i;
        break;
      }
    }
    _commands.showOverview([
      for (var i = from; i < points.length; i++) points[i].point,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomStreamProvider(roomCode)).value;
    final map = ref.watch(rideMapControllerProvider(roomCode));
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    final end = ref.watch(rideEndControllerProvider(roomCode));
    ref.watch(roomPresenceProvider(roomCode));
    final guided = widget.guided;
    final guidance = guided
        ? ref.watch(guidanceControllerProvider(roomCode))
        : null;
    final safety = ref.watch(safetyControllerProvider(roomCode));
    if (guided) {
      ref.listen<GuidanceState>(
        guidanceControllerProvider(roomCode),
        _onGuidanceChanged,
      );
    }
    ref.listen<SafetyState>(safetyControllerProvider(roomCode), _onSafetyChanged);
    ref.listen<RideEndState>(rideEndControllerProvider(roomCode), (_, next) {
      if (next.completed && !_saved.isCompleted) _saved.complete();
    });
    ref.listen<AsyncValue<Room?>>(roomStreamProvider(roomCode), (
      previous,
      next,
    ) {
      if (previous?.value?.status != RoomStatus.ended &&
          next.value?.status == RoomStatus.ended) {
        _frameFinishedRide();
      }
    });
    listenToRoomFlow(
      ref,
      context,
      code: roomCode,
      currentPath: guided
          ? AppRoutes.ridePath(roomCode)
          : AppRoutes.freeRidePath(roomCode),
      beforeLeaving: _holdBeforeResults,
    );

    // Until the room is known nothing group-only is shown, so a solo ride
    // never flashes the group's tools.
    final isGroupRide = (room?.members.length ?? 0) > 1;
    final status = room?.status;
    // Every rider ends their own ride, whenever they like.
    final canEnd =
        status == RoomStatus.riding && !end.isEnding && !end.completed;
    final autoEnd = canEnd
        ? ref.watch(autoEndControllerProvider(roomCode))
        : null;
    // The wrap-up covers the screen from the moment the ride starts ending
    // until the results open, so nobody is left looking at a stalled map.
    final progress = RideEndProgress.of(
      status: status,
      end: end,
      ownRecordSaved: map.isFinalSaved,
    );

    if (guidance != null &&
        !_introPlayed &&
        guidance.guide != null &&
        guidance.snapshot != null) {
      _introPlayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playIntro(ref.read(guidanceControllerProvider(roomCode)));
      });
    }

    final snapshot = guidance?.snapshot;
    final guide = guidance?.guide;
    final alerts = safety.alerts;
    final fix = map.myFix;
    return RoomExitScope(
      roomCode: roomCode,
      builder: (context, _, _) => PopScope(
        // Going back mid-wrap-up would leave the ride half ended.
        canPop: progress == null,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              Positioned.fill(
                // The map fades in over the loader once the first fix lands.
                child: AnimatedSwitcher(
                  duration: AppMotion.slow,
                  switchInCurve: AppMotion.curve,
                  switchOutCurve: AppMotion.exit,
                  child: fix == null
                      ? const _Locating(key: ValueKey('locating'))
                      : RepaintBoundary(
                          key: const ValueKey('map'),
                          child: OsmMapWidget(
                            initialCenter: fix.point,
                            markers: _markers(map, snapshot),
                            trails: _trails(map),
                            nowMs: map.nowMs,
                            myUid: myUid,
                            riderCardBuilder: (uid) =>
                                RiderInfoCard(roomCode: roomCode, uid: uid),
                            bottomInset: _panelInset,
                            commands: _commands,
                            completionPoint: status == RoomStatus.ended
                                ? fix.point
                                : null,
                            completionColor: _color(map.colorIds[myUid]),
                            routeLayer: guide == null
                                ? null
                                : GuidedRouteLayer(
                                    guide: guide,
                                    progressMeters: snapshot?.alongMeters ?? 0,
                                    activeEndMeters: snapshot?.activeEndMeters,
                                    nextTurn: snapshot?.next?.point,
                                    hasArrived: snapshot?.hasArrived ?? false,
                                  ),
                            headingOverride:
                                guidance != null &&
                                    guidance.canUseRouteHeading
                                ? snapshot!.routeBearing
                                : null,
                            returnTarget: guidance != null &&
                                    guidance.isReturning
                                ? snapshot?.rejoinPoint
                                : null,
                            fuel: ref.watch(fuelStationControllerProvider),
                            showFuel:
                                ref.watch(fuelLayerVisibleProvider) ?? false,
                            onFuelStationTap: (station) {
                              final me = ref
                                  .read(rideMapControllerProvider(roomCode))
                                  .myFix;
                              showFuelStationSheet(
                                context,
                                station: station,
                                from: me?.point,
                                speedMps: me?.speedMps,
                              );
                            },
                          ),
                        ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RideMapHeader(
                        rideName: room?.name ?? '',
                        code: roomCode,
                        // Safety tools are about the group: none on a solo
                        // ride (a room with only this rider).
                        trailing: isGroupRide
                            ? SafetyButton(
                                alertActive: safety.needsAttention,
                                onPressed: () => showSafetySheet(
                                  context,
                                  code: roomCode,
                                  guided: guided,
                                ),
                              )
                            : null,
                      ),
                      if (guidance != null && snapshot != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        GuidanceCard(
                          state: guidance,
                          destinationName:
                              guide?.route.destinationName ?? 'Destination',
                          headingDegrees: map.myFix?.headingDegrees,
                          rideDuration:
                              map.myStats?.elapsed(map.nowMs) ?? Duration.zero,
                          rideDistanceMeters: map.myStats?.distanceMeters ?? 0,
                          onReturn: () => ref
                              .read(guidanceControllerProvider(roomCode).notifier)
                              .returnToRoute(),
                          onContinue: () => ref
                              .read(guidanceControllerProvider(roomCode).notifier)
                              .continueOffRoute(),
                          onAcknowledgeArrival: () => ref
                              .read(guidanceControllerProvider(roomCode).notifier)
                              .acknowledgeArrival(),
                        ),
                      ],
                      AnimatedSize(
                        duration: AppMotion.normal,
                        curve: AppMotion.curve,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: AppMotion.normal,
                          switchInCurve: AppMotion.curve,
                          switchOutCurve: AppMotion.exit,
                          child: alerts.isEmpty
                              ? const SizedBox(
                                  key: ValueKey('no-signal'),
                                  width: double.infinity,
                                )
                              : Padding(
                                  key: ValueKey(
                                    '${alerts.first.uid}:${alerts.first.sentAtMs}',
                                  ),
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.sm,
                                  ),
                                  child: _signalBanner(room, map, alerts),
                                ),
                        ),
                      ),
                      // The leaderboard takes the free space between the
                      // cards above and the controls below, so whatever
                      // opens or grows around it, it never covers them. On
                      // the left and narrow, it stays clear of this rider's
                      // marker in the middle and the map buttons on the
                      // right.
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: LiveLeaderboard(
                              roomCode: roomCode,
                              maxWidth: _leaderboardWidth(context),
                            ),
                          ),
                        ),
                      ),
                      _MapControls(
                        commands: _commands,
                        onOverview: guide == null
                            ? null
                            : () => _commands.showOverview(
                                guide.geometry.points,
                              ),
                        // Pause and End: always in view while riding.
                        rideActions: canEnd
                            ? RideActionButtons(
                                isPaused: map.isPaused,
                                onPause: () => ref
                                    .read(
                                      rideMapControllerProvider(
                                        roomCode,
                                      ).notifier,
                                    )
                                    .pause(),
                                onResume: () => ref
                                    .read(
                                      rideMapControllerProvider(
                                        roomCode,
                                      ).notifier,
                                    )
                                    .resume(),
                                onEnd: () => _confirmEnd(isGroupRide),
                              )
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _Attribution(),
                      const SizedBox(height: AppSpacing.sm),
                      // The map is told how tall the panel is, so the camera
                      // keeps the rider clear of it however far it opens.
                      NotificationListener<SizeChangedLayoutNotification>(
                        onNotification: (_) {
                          _measurePanel();
                          return false;
                        },
                        child: SizeChangedLayoutNotifier(
                          key: _panelKey,
                          child: RideControlPanel(
                            leading: snapshot == null
                                ? null
                                : RouteProgressStrip(snapshot: snapshot),
                            routeFigures: snapshot == null
                                ? const []
                                : _routeFigures(snapshot),
                            speedKmh: map.speedKmh,
                            isConnected: map.isConnected,
                            gps: map.gps,
                            duration:
                                map.myStats?.elapsed(map.nowMs) ??
                                Duration.zero,
                            movingTime:
                                map.myStats?.movingTime ?? Duration.zero,
                            stoppedTime:
                                map.myStats?.stoppedTime(map.nowMs) ??
                                Duration.zero,
                            averageSpeedMps: map.myStats?.averageSpeedMps ?? 0,
                            distanceMeters: map.myStats?.distanceMeters ?? 0,
                            riderCount: room?.members.length ?? 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Riders leaving or rejoining the path: a banner that slides
              // down over the header for a few seconds.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: RideEventBanner(roomCode: roomCode),
                  ),
                ),
              ),
              // The auto-end question, over the bottom of the map. Only one at
              // a time; it leaves by itself if the rider moves.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AnimatedSwitcher(
                      duration: AppMotion.slow,
                      switchInCurve: AppMotion.spring,
                      switchOutCurve: AppMotion.exit,
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: autoEnd == null || progress != null
                          ? const SizedBox(
                              key: ValueKey('no-auto-end'),
                              width: double.infinity,
                            )
                          : AutoEndSheet(
                              key: const ValueKey('auto-end'),
                              prompt: autoEnd,
                              onContinue: () => ref
                                  .read(
                                    autoEndControllerProvider(roomCode).notifier,
                                  )
                                  .keepRiding(),
                              onPause: () => ref
                                  .read(
                                    autoEndControllerProvider(roomCode).notifier,
                                  )
                                  .pauseRide(),
                              onEnd: () => ref
                                  .read(
                                    autoEndControllerProvider(roomCode).notifier,
                                  )
                                  .endNow(),
                            ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: progress == null,
                  child: AnimatedSwitcher(
                    duration: AppMotion.slow,
                    switchInCurve: AppMotion.curve,
                    switchOutCurve: AppMotion.exit,
                    child: progress == null
                        ? const SizedBox.shrink(key: ValueKey('no-overlay'))
                        : progress.stage == RideEndStage.complete
                        ? RideCompleteOverlay(
                            key: const ValueKey('complete'),
                            // Each rider names their own ride on the results,
                            // from where it ended.
                            rideName: '',
                            distanceMeters: map.myStats?.distanceMeters ?? 0,
                            duration:
                                map.myStats?.elapsed(
                                  DateTime.now().millisecondsSinceEpoch,
                                ) ??
                                Duration.zero,
                            averageSpeedMps: map.myStats?.averageSpeedMps ?? 0,
                            accent: _color(map.colorIds[myUid]),
                            onContinue: _openResults,
                          )
                        : RideEndingOverlay(
                            key: const ValueKey('overlay'),
                            stage: progress.stage,
                            error: progress.error,
                            onRetry: () => ref
                                .read(
                                  rideEndControllerProvider(roomCode).notifier,
                                )
                                .endRide(),
                            onDismiss: () => ref
                                .read(
                                  rideEndControllerProvider(roomCode).notifier,
                                )
                                .dismissError(),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _color(String? colorId) =>
      RiderPalette.colorById(colorId)?.color ?? AppColors.textPrimary;

  /// Where to draw each rider. Rebuilding this list is cheap, and riders
  /// whose position did not change keep gliding undisturbed.
  ///
  /// On a guided route, this rider's own marker sits on the route line while
  /// they are within a few metres of it, so GPS wobble does not shake it off
  /// the road. Only the drawing moves; the shared position is untouched.
  static List<MarkerTarget> _markers(
    RideMapState map,
    GuidanceSnapshot? snapshot,
  ) => [
    for (final rider in map.riders.values)
      MarkerTarget(
        uid: rider.uid,
        point:
            rider.isMe &&
                snapshot != null &&
                !snapshot.isOffRoute &&
                !snapshot.hasArrived &&
                snapshot.offsetMeters <= _snapMeters &&
                identical(map.myFix?.point, snapshot.riderPoint)
            ? snapshot.snappedPoint
            : rider.point,
        color: _color(rider.colorId),
        headingDegrees: rider.isMoving ? rider.headingDegrees : null,
        isMe: rider.isMe,
        speedMps: rider.isMoving ? rider.speedMps : null,
      ),
  ];

  /// Widest the leaderboard may be: it stops short of the middle of the
  /// screen, where the camera keeps this rider's marker, by the marker's
  /// size and a margin.
  static double _leaderboardWidth(BuildContext context) {
    const markerClearance = 34.0;
    const widest = 220.0;
    final half = MediaQuery.sizeOf(context).width / 2;
    return math.min(widest, half - AppSpacing.lg - markerClearance);
  }

  /// The open panel's route figures: what is left, how far along, and how
  /// far from the planned line.
  static List<(String, String)> _routeFigures(GuidanceSnapshot snapshot) => [
    ('REMAINING', RideFormat.distance(snapshot.remainingMeters)),
    ('PROGRESS', '${(snapshot.fraction * 100).floor()}%'),
    ('OFF LINE', guidanceDistance(snapshot.offsetMeters)),
  ];

  Widget _signalBanner(
    Room? room,
    RideMapState map,
    List<RideSignal> alerts,
  ) {
    final signal = alerts.first;
    final name =
        room?.memberByUid(signal.uid)?.displayName?.trim().isNotEmpty == true
        ? room!.memberByUid(signal.uid)!.displayName!.trim()
        : 'A rider';
    // Their live position if they are on the map, else where they sent it.
    final where = map.riders[signal.uid]?.point ?? signal.point;
    return RideSignalBanner(
      signal: signal,
      name: name,
      myPoint: map.myFix?.point,
      moreCount: alerts.length - 1,
      onShow: where == null ? null : () => _commands.focus(where),
    );
  }

  static List<TrailStyle> _trails(RideMapState map) => [
    for (final entry in map.trails.entries)
      TrailStyle(trail: entry.value, color: _color(map.colorIds[entry.key])),
  ];
}

/// Round map controls at the right edge, above the panel: the route overview
/// (guided rides) and, once the camera stops following, a recenter button
/// that springs in.
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.commands,
    required this.onOverview,
    this.rideActions,
  });

  final LiveMapCommands commands;

  /// Pause and End, at the foot of the controls; `null` once the ride is no
  /// longer this rider's to end.
  final Widget? rideActions;
  final VoidCallback? onOverview;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ValueListenableBuilder<bool>(
        valueListenable: commands.isFollowing,
        builder: (context, following, _) => Column(
          mainAxisSize: MainAxisSize.min,
          // Right-aligned, so the fuel row's ⓘ sits to the left of the
          // buttons' column.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ⓘ: fuel information. ⛽: tap to turn fuel stations on or off.
            const FuelControls(),
            if (onOverview != null) const SizedBox(height: AppSpacing.sm),
            if (onOverview != null)
              MapFloatingButton(
                icon: Icons.route_rounded,
                tooltip: 'Show the whole route',
                onPressed: onOverview!,
              ),
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              child: following
                  ? const SizedBox(width: 44)
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: FadeScaleIn(
                        duration: AppMotion.springDuration,
                        spring: true,
                        child: MapFloatingButton(
                          icon: Icons.navigation_rounded,
                          tooltip: 'Follow me again',
                          color: AppColors.primary,
                          onPressed: commands.recenter,
                        ),
                      ),
                    ),
            ),
            if (rideActions != null) ...[
              const SizedBox(height: AppSpacing.md),
              rideActions!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Locating extends StatelessWidget {
  const _Locating({super.key});

  @override
  Widget build(BuildContext context) {
    return const RideLoaderMessage(message: 'Finding your position…');
  }
}

/// Required credit for OpenStreetMap data.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '© OpenStreetMap contributors',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}
