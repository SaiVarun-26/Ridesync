import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/rider_palette.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/pulse_indicator.dart';
import '../../domain/live/connection_quality.dart';
import '../../domain/live/ride_format.dart';
import '../providers/ride_map_providers.dart';
import '../providers/rider_stats_providers.dart';

/// The frosted card shown when a rider taps another rider's dot.
///
/// Leads with who it is (avatar and name) and how fast they are going right
/// now, which updates live. Beneath: which way they are heading, how far
/// they have come, and how good their connection is. The rider's colour edges
/// the card thinly, tying it to the dot it belongs to.
class RiderInfoCard extends ConsumerWidget {
  const RiderInfoCard({super.key, required this.roomCode, required this.uid});

  final String roomCode;
  final String uid;

  static const double width = 244;
  static const double _kmhPerMps = 3.6;
  static const double _speedSize = 44;

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
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: GlassPanel(
        accent: accent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(name: name, color: accent),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _LivePill(isLive: quality != ConnectionQuality.offline),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // Counts smoothly from one reading to the next.
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: speedKmh.toDouble()),
                        duration: AppMotion.normal,
                        curve: AppMotion.curve,
                        builder: (context, value, _) => Text(
                          '${value.round()}',
                          style: AppTypography.stat(fontSize: _speedSize),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text('km/h', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _Heading(degrees: rider.isMoving ? rider.headingDegrees : null),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        RideFormat.distance(stats?.distanceMeters ?? 0),
                        style: AppTypography.stat(
                          fontSize: AppTypeScale.statSmall,
                        ),
                      ),
                      Text(
                        'travelled',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
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
}

/// The rider's initial on a disc tinted with their colour.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color});

  final String name;
  final Color color;

  static const double _size = 38;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : String.fromCharCode(name.trim().runes.first).toUpperCase();
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// A small compass: an arrow pointing the way the rider is heading, with the
/// compass point beside it. Dimmed and empty while they are standing still.
class _Heading extends StatelessWidget {
  const _Heading({required this.degrees});

  final double? degrees;

  static const double _dial = 40;

  @override
  Widget build(BuildContext context) {
    final heading = degrees;
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: _dial,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: AppColors.border),
            ),
            child: heading == null
                ? const Icon(
                    Icons.pause_rounded,
                    size: AppIconSize.medium,
                    color: AppColors.textTertiary,
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: heading),
                    duration: AppMotion.normal,
                    curve: AppMotion.curve,
                    builder: (context, value, child) => Transform.rotate(
                      angle: value * math.pi / 180,
                      child: child,
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      size: AppIconSize.medium,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 28,
          child: Text(
            heading == null ? '—' : RideFormat.compass(heading),
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Marks that the speed on the card is updating in real time.
class _LivePill extends StatelessWidget {
  const _LivePill({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final color = isLive ? AppColors.success : AppColors.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDot(color: color, live: isLive),
        const SizedBox(width: AppSpacing.sm),
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
      ConnectionQuality.good => AppColors.success,
      ConnectionQuality.fair => AppColors.textSecondary,
      ConnectionQuality.poor => AppColors.error,
      ConnectionQuality.offline => AppColors.textTertiary,
    };
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      padding: AppSpacing.pill,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: color),
          const SizedBox(width: AppSpacing.sm),
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
