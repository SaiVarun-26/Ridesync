import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import 'widgets/ride_stage_screen.dart';

/// Guided-ride planning stage for room [roomCode].
///
/// Every rider lands here after initialization when the host chooses Guided
/// Ride. Destination search and routing will use free, open data sources in a
/// later milestone; the room flow, presence, and leave handling already work.
class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return RideStageScreen(
      roomCode: roomCode,
      currentPath: AppRoutes.planningPath(roomCode),
      title: 'Guided Ride',
      subtitle: 'Destination Selection',
      caption: 'Coming in a later update',
    );
  }
}
