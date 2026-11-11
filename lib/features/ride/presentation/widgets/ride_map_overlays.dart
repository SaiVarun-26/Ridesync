import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/section_label.dart';
import '../ride_map_controller.dart';

/// Top of the live map: the ride's name and code.
class RideMapHeader extends StatelessWidget {
  const RideMapHeader({super.key, required this.rideName, required this.code});

  final String rideName;
  final String code;

  static const double _codeSpacing = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rideName,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            code,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: _codeSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

/// Speed, connection, and GPS status: the always-visible row of the bottom
/// ride panel.
class RideStatusRow extends StatelessWidget {
  const RideStatusRow({
    super.key,
    required this.speedKmh,
    required this.isConnected,
    required this.gps,
  });

  final double speedKmh;
  final bool isConnected;
  final GpsStatus gps;

  static const double _speedSize = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (gpsLabel, gpsColor) = switch (gps) {
      GpsStatus.locked => ('GPS Locked', AppColors.neonGreen),
      GpsStatus.weak => ('GPS Weak', AppColors.yellow),
      GpsStatus.searching => ('Searching GPS', AppColors.textTertiary),
    };
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  speedKmh.round().toString(),
                  style: AppTypography.stat(fontSize: _speedSize),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('km/h', style: theme.textTheme.bodySmall),
              ],
            ),
            const SectionLabel('SPEED'),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusLine(
              label: isConnected ? 'Live' : 'Reconnecting',
              color: isConnected ? AppColors.neonGreen : AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.sm),
            _StatusLine(label: gpsLabel, color: gpsColor),
          ],
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.color});

  final String label;
  final Color color;

  static const double _dotSize = 7;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppMotion.normal,
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
