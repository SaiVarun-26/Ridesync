import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';

/// End-of-ride shareable Ride Card for the ride identified by [rideId].
///
/// Milestone 1 provides the route and shell. The designed, exportable PNG card
/// (stats, mini route map, rider trails, share action) lands in Milestone 7.
class RideCardScreen extends ConsumerWidget {
  const RideCardScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Card')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Ride Card (Milestone 7)',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}
