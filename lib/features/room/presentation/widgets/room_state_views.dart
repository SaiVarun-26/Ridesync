import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Centered spinner shown while a room is loading.
class RoomLoadingView extends StatelessWidget {
  const RoomLoadingView({super.key});

  static const double _size = 28;
  static const double _strokeWidth = 2;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        height: _size,
        width: _size,
        child: CircularProgressIndicator(
          strokeWidth: _strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Centered message for room states with nothing else to show, such as a load
/// error or a room that no longer exists.
class RoomMessageView extends StatelessWidget {
  const RoomMessageView({super.key, required this.message});

  final String message;

  /// Shown when the room stream fails.
  static const String loadError =
      'Could not load this ride. Please try again.';

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
