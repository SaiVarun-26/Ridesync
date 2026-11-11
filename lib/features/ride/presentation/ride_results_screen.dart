import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_button.dart';
import '../../history/presentation/providers/ride_history_providers.dart';
import '../../history/presentation/providers/ride_transition_providers.dart';
import 'widgets/ride_stage_screen.dart';

/// Where every rider lands when the host ends the ride.
///
/// Reaching it adds the ride to the rider's history, and from here the rider
/// can open the full ride.
class RideResultsScreen extends ConsumerWidget {
  const RideResultsScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched only to keep it alive while this screen is open.
    ref.watch(recordRideHistoryProvider(roomCode));
    return RideStageScreen(
      roomCode: roomCode,
      currentPath: AppRoutes.resultsPath(roomCode),
      title: 'Ride Complete',
      subtitle: 'Your results are ready.',
      caption: 'Saved to your ride history',
      leading: const _CompleteBadge(),
      actions: [
        GlowButton(
          label: 'View ride',
          icon: Icons.route_rounded,
          accent: AppColors.neonGreen,
          foreground: AppColors.background,
          onPressed: () {
            // No card to grow out of here, so the details simply fade in.
            ref.read(rideTransitionOriginProvider.notifier).set(null);
            context.push(AppRoutes.historyDetailsPath(roomCode));
          },
        ),
      ],
    );
  }
}

/// A neon ring that draws itself, then its check mark pops in.
class _CompleteBadge extends StatelessWidget {
  const _CompleteBadge();

  static const double _size = 84;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final check = Curves.easeOutBack.transform(
          ((t - 0.45) / 0.55).clamp(0.0, 1.0),
        );
        return SizedBox.square(
          dimension: _size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: _size,
                child: CircularProgressIndicator(
                  value: t,
                  strokeWidth: 3,
                  color: AppColors.neonGreen,
                  backgroundColor: AppColors.divider,
                ),
              ),
              Transform.scale(
                scale: check,
                child: Opacity(
                  opacity: check.clamp(0.0, 1.0),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: AppColors.neonGreen,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
