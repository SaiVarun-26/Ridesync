import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/rider_palette.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../room/domain/room.dart';
import '../../room/domain/room_status.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../../room/presentation/room_flow.dart';
import '../../room/presentation/widgets/room_exit_scope.dart';
import '../../room/presentation/widgets/room_state_views.dart';
import 'map/marker_interpolator.dart';
import 'map/osm_map_widget.dart';
import 'map/trail_layer.dart';
import 'providers/ride_completion_providers.dart';
import 'providers/ride_map_providers.dart';
import 'ride_map_controller.dart';
import 'widgets/ride_control_panel.dart';
import 'widgets/ride_ending_overlay.dart';
import 'widgets/ride_map_overlays.dart';
import 'widgets/rider_info_card.dart';

/// The Free Roam live map for room [roomCode].
///
/// Every rider appears as a glowing dot in their color with a fading trail;
/// positions sync in real time and the camera follows this rider. All ride
/// logic lives in [RideMapController]; this screen only lays out the map and
/// its two overlays.
class RideMapScreen extends ConsumerStatefulWidget {
  const RideMapScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<RideMapScreen> createState() => _RideMapScreenState();
}

class _RideMapScreenState extends ConsumerState<RideMapScreen> {
  String get roomCode => widget.roomCode;

  /// How long the finished wrap-up stays on screen before the results open,
  /// so the last step is seen to complete.
  static const Duration _completeHold = Duration(milliseconds: 900);

  Future<void>? _hold;

  final GlobalKey _panelKey = GlobalKey();

  /// How much of the map's bottom the ride panel covers, in pixels.
  final ValueNotifier<double> _panelInset = ValueNotifier<double>(0);

  /// Space kept between the panel and the rider.
  static const double _panelClearance = 8;

  @override
  void dispose() {
    _panelInset.dispose();
    super.dispose();
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
    if (room.status != RoomStatus.ended) return Future<void>.value();
    return _hold ??= Future<void>.delayed(_completeHold);
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomStreamProvider(roomCode)).value;
    final map = ref.watch(rideMapControllerProvider(roomCode));
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    final end = ref.watch(rideEndControllerProvider(roomCode));
    ref.watch(roomPresenceProvider(roomCode));
    listenToRoomFlow(
      ref,
      context,
      code: roomCode,
      currentPath: AppRoutes.freeRidePath(roomCode),
      beforeLeaving: _holdBeforeResults,
    );

    final isHost = myUid != null && room?.hostUid == myUid;
    final status = room?.status;
    final canEnd =
        isHost && (status == RoomStatus.riding || status == RoomStatus.ending);
    // The wrap-up covers the screen from the moment the ride starts ending
    // until the results open, so nobody is left looking at a stalled map.
    final progress = RideEndProgress.of(
      status: status,
      isHost: isHost,
      end: end,
      ownRecordSaved: map.isFinalSaved,
    );

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
                child: fix == null
                    ? const _Locating()
                    : OsmMapWidget(
                        initialCenter: fix.point,
                        markers: _markers(map),
                        trails: _trails(map),
                        nowMs: map.nowMs,
                        myUid: myUid,
                        riderCardBuilder: (uid) =>
                            RiderInfoCard(roomCode: roomCode, uid: uid),
                        bottomInset: _panelInset,
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RideMapHeader(rideName: room?.name ?? '', code: roomCode),
                      const Spacer(),
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
                            speedKmh: map.speedKmh,
                            isConnected: map.isConnected,
                            gps: map.gps,
                            duration:
                                map.myStats?.elapsed(map.nowMs) ??
                                Duration.zero,
                            distanceMeters: map.myStats?.distanceMeters ?? 0,
                            riderCount: room?.members.length ?? 0,
                            isHost: isHost,
                            canEnd: canEnd,
                            isEnding: end.isEnding,
                            onEndRide: () => ref
                                .read(
                                  rideEndControllerProvider(roomCode).notifier,
                                )
                                .endRide(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: progress == null,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: progress == null
                        ? const SizedBox.shrink(key: ValueKey('no-overlay'))
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
  static List<MarkerTarget> _markers(RideMapState map) => [
    for (final rider in map.riders.values)
      MarkerTarget(
        uid: rider.uid,
        point: rider.point,
        color: _color(rider.colorId),
        headingDegrees: rider.isMoving ? rider.headingDegrees : null,
        isMe: rider.isMe,
      ),
  ];

  static List<TrailStyle> _trails(RideMapState map) => [
    for (final entry in map.trails.entries)
      TrailStyle(trail: entry.value, color: _color(map.colorIds[entry.key])),
  ];
}

class _Locating extends StatelessWidget {
  const _Locating();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: RoomMessageView(message: 'Finding your position…'),
    );
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
