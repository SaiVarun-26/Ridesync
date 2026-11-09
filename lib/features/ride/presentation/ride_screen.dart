import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';

/// The live ride map for the ride identified by [rideId] — the heart of the
/// app.
///
/// Milestone 1 renders the top bar and leave control over a placeholder map
/// surface. The night-styled Google Map, route polyline, live positions, and
/// the Smart Trail Rendering Engine land in Milestones 4, 5 and 6.
class RideScreen extends ConsumerWidget {
  const RideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // Placeholder for the map layer (added in Milestone 4).
          const Positioned.fill(child: ColoredBox(color: Color(0xFF070707))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'Live map (Milestone 4+)',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
