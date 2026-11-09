import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import 'widgets/ride_stage_screen.dart';

/// Free-roam ride stage for room [roomCode].
///
/// Every rider lands here when the host chooses Free Roam. The live ride
/// arrives in Milestone 4.5.
class FreeRideScreen extends StatelessWidget {
  const FreeRideScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return RideStageScreen(
      roomCode: roomCode,
      currentPath: AppRoutes.freeRidePath(roomCode),
      title: 'Free Ride',
      subtitle: 'Preparing Live Ride...',
      caption: 'Milestone 4.5',
    );
  }
}
