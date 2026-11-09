import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/rider_palette.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../domain/live/connection_quality.dart';
import '../../domain/live/ride_format.dart';
import '../providers/ride_map_providers.dart';
import '../providers/rider_stats_providers.dart';

/// Floating glass card shown when a rider taps another rider's dot: name,
/// current speed, distance travelled, and connection quality.
class RiderInfoCard extends ConsumerWidget {
  const RiderInfoCard({super.key, required this.roomCode, required this.uid});

  final String roomCode;
  final String uid;

  static const double width = 208;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(rideMapControllerProvider(roomCode));
    final rider = map.riders[uid];
    if (rider == null) return const SizedBox.shrink();
    final stats = ref.watch(roomRideStatsProvider(roomCode)).value?[uid];

    final palette = RiderPalette.colorById(rider.colorId);
    final accent = palette?.color ?? AppColors.textPrimary;
    final name = rider.displayName?.trim().isNotEmpty == true
        ? rider.displayName!.trim()
        : (palette?.label ?? 'Rider');
    final received = rider.receivedAtMs;
    final quality = received == null
        ? (map.isConnected ? ConnectionQuality.good : ConnectionQuality.offline)
        : ConnectionQuality.fromAge(
            Duration(milliseconds: map.nowMs - received),
          );
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: GlassPanel(
        glowColor: accent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Dot(color: accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _Line(
              label: 'Speed',
              value: RideFormat.speed(rider.speedMps ?? 0),
            ),
            _Line(
              label: 'Distance',
              value: RideFormat.distance(stats?.distanceMeters ?? 0),
            ),
            _Line(
              label: 'Connection',
              value: quality.label,
              valueColor: switch (quality) {
                ConnectionQuality.good => AppColors.neonGreen,
                ConnectionQuality.fair => AppColors.yellow,
                ConnectionQuality.poor => AppColors.warning,
                ConnectionQuality.offline => AppColors.textTertiary,
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  static const double _size = 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.stat(fontSize: 14).copyWith(
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
