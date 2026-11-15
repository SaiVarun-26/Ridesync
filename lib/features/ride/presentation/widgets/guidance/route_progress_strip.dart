import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/guidance/route_progress.dart';
import '../../../domain/live/ride_format.dart';

/// A slim progress line for the guided route, with what is left to ride: the
/// one route figure that stays on screen while the ride panel is closed.
class RouteProgressStrip extends StatelessWidget {
  const RouteProgressStrip({super.key, required this.snapshot});

  final GuidanceSnapshot snapshot;

  static const double _barHeight = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = snapshot.hasArrived
        ? 'Destination reached'
        : [
            '${RideFormat.distance(snapshot.remainingMeters)} left',
            if (snapshot.remainingTime != null)
              RideFormat.eta(snapshot.remainingTime!),
          ].join(' · ');
    final percent = (snapshot.fraction * 100).floor();
    return Semantics(
      label: 'Route progress $percent percent. $left',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              Text(
                '$percent%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: _barHeight,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: snapshot.fraction),
                duration: AppMotion.slow,
                curve: AppMotion.curve,
                builder: (context, value, _) => CustomPaint(
                  painter: _BarPainter(value),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = AppColors.border)
      ..drawRect(
        Offset.zero & Size(size.width * value.clamp(0.0, 1.0), size.height),
        Paint()..color = AppColors.primary,
      );
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.value != value;
}
