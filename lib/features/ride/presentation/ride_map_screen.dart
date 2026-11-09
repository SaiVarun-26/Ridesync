import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/rider_palette.dart';
import '../../auth/presentation/providers/auth_providers.dart';
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
import 'widgets/end_ride_controls.dart';
import 'widgets/ride_map_overlays.dart';
import 'widgets/rider_info_card.dart';

/// The Free Roam live map for room [roomCode].
///
/// Every rider appears as a glowing dot in their color with a fading trail;
/// positions sync in real time and the camera follows this rider. All ride
/// logic lives in [RideMapController]; this screen only lays out the map and
/// its two overlays.
class RideMapScreen extends ConsumerWidget {
  const RideMapScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    );
    ref.listen(
      rideEndControllerProvider(roomCode).select((s) => s.errorId),
      (_, _) {
        final error = ref.read(rideEndControllerProvider(roomCode)).error;
        if (error == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      },
    );

    final isHost = myUid != null && room?.hostUid == myUid;
    final status = room?.status;
    // While the room is ending, riders (and the host, once ending is under
    // way) see a wrap-up state. If ending failed part-way the room stays in
    // `ending`, so the host gets the button back to try again.
    final showBanner = status == RoomStatus.ending && (!isHost || end.isEnding);
    final showEndButton = isHost &&
        !showBanner &&
        (status == RoomStatus.riding || status == RoomStatus.ending);

    final fix = map.myFix;
    return RoomExitScope(
      roomCode: roomCode,
      builder: (context, _, _) => Scaffold(
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
                    if (showBanner) ...[
                      RideEndingBanner(isHost: isHost),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (showEndButton) ...[
                      EndRideButton(
                        isEnding: end.isEnding,
                        onPressed: () => _confirmAndEnd(context, ref),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    RideStatusCard(
                      speedKmh: map.speedKmh,
                      isConnected: map.isConnected,
                      gps: map.gps,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndEnd(BuildContext context, WidgetRef ref) async {
    if (!await confirmEndRide(context)) return;
    await ref.read(rideEndControllerProvider(roomCode).notifier).endRide();
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
          TrailStyle(
            trail: entry.value,
            color: _color(map.colorIds[entry.key]),
          ),
      ];
}

class _Locating extends StatelessWidget {
  const _Locating();

  @override
  Widget build(BuildContext context) {
    return const Center(child: RoomMessageView(message: 'Finding your position…'));
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
            ),
      ),
    );
  }
}
