import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/rider_palette.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/pulse_indicator.dart';
import '../../domain/live/connection_quality.dart';
import '../../domain/live/ride_format.dart';
import '../providers/ride_map_providers.dart';
import '../providers/rider_stats_providers.dart';

/// Floating glass card shown when a rider taps another rider's dot.
///
/// Reads, in order of importance: the rider's current speed (live), the
/// distance they have covered, and how good their connection is. Their colour
/// ties the card to the dot it belongs to.
class RiderInfoCard extends ConsumerWidget {
  const RiderInfoCard({super.key, required this.roomCode, required this.uid});

  final String roomCode;
  final String uid;

  static const double width = 216;

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
    final speedKmh = ((rider.speedMps ?? 0) * _kmhPerMps).round();

    return SizedBox(
      width: width,
      child: GlassPanel(
        glowColor: accent,
        radius: AppRadius.card,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ColorDot(color: accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _LivePill(isLive: quality != ConnectionQuality.offline),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$speedKmh',
                  style: AppTypography.stat(fontSize: _speedSize),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('km/h', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        RideFormat.distance(stats?.distanceMeters ?? 0),
                        style: AppTypography.stat(fontSize: _distanceSize),
                      ),
                      Text(
                        'distance',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                _QualityBadge(quality: quality),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const double _kmhPerMps = 3.6;
  static const double _speedSize = 40;
  static const double _distanceSize = 16;
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  static const double _size = 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
        ],
      ),
    );
  }
}

/// Marks that the speed above is updating in real time.
class _LivePill extends StatelessWidget {
  const _LivePill({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final color = isLive ? AppColors.neonGreen : AppColors.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLive)
          PulseIndicator(color: color, size: 6)
        else
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          isLive ? 'LIVE' : 'OFFLINE',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: color, letterSpacing: 1.2),
        ),
      ],
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.quality});

  final ConnectionQuality quality;

  @override
  Widget build(BuildContext context) {
    final color = switch (quality) {
      ConnectionQuality.good => AppColors.neonGreen,
      ConnectionQuality.fair => AppColors.yellow,
      ConnectionQuality.poor => AppColors.warning,
      ConnectionQuality.offline => AppColors.textTertiary,
    };
    return AnimatedContainer(
      duration: AppMotion.normal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            quality.label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
