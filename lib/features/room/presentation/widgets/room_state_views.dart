import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/ride_loader.dart';

/// Centered spinner shown while a room is loading.
class RoomLoadingView extends StatelessWidget {
  const RoomLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const RideLoaderMessage();
  }
}

/// Centered message for room states with nothing else to show, such as a load
/// error or a room that no longer exists.
class RoomMessageView extends StatelessWidget {
  const RoomMessageView({super.key, required this.message});

  final String message;

  /// Shown when the room stream fails.
  static const String loadError = 'Could not load this ride. Please try again.';

  /// Shown when the room no longer exists.
  static const String unavailable = 'This ride is no longer available.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
