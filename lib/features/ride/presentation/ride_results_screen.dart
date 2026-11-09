import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import 'widgets/ride_stage_screen.dart';

/// Where every rider lands when the host ends the ride.
///
/// For now this only confirms the ride is over and keeps the rider in sync with
/// the room. The ride summary is already saved for the room; the results and
/// shareable cards are built on top of it in the next milestone.
class RideResultsScreen extends StatelessWidget {
  const RideResultsScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return RideStageScreen(
      roomCode: roomCode,
      currentPath: AppRoutes.resultsPath(roomCode),
      title: 'Ride Complete',
      subtitle: 'Your results are ready.',
      caption: 'Ride cards arrive in the next update',
    );
  }
}
