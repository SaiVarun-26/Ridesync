import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/glow_button.dart';
import '../../../../core/widgets/pulse_indicator.dart';

/// Asks the host to confirm ending the ride for everyone. Returns whether they
/// confirmed.
Future<bool> confirmEndRide(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('End this ride?'),
      content: const Text(
        'Tracking stops for everyone and the ride results are saved.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep riding'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.warning),
          child: const Text('End Ride'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The host's End Ride button, shown over the map while the ride is going.
class EndRideButton extends StatelessWidget {
  const EndRideButton({
    super.key,
    required this.isEnding,
    required this.onPressed,
  });

  final bool isEnding;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlowButton(
      label: 'End Ride',
      variant: GlowButtonVariant.destructive,
      isLoading: isEnding,
      onPressed: onPressed,
    );
  }
}

/// Shown to everyone while the ride is being wrapped up.
///
/// The host sees that results are being prepared; riders see that they are
/// waiting for the host.
class RideEndingBanner extends StatelessWidget {
  const RideEndingBanner({super.key, required this.isHost});

  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PulseIndicator(color: AppColors.neonGreen),
          const SizedBox(width: AppSpacing.md),
          Text(
            isHost ? 'Wrapping up the ride…' : 'Waiting for host to finish...',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
