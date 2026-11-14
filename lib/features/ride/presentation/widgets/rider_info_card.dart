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
import '../../domain/live/relative_position.dart';
import '../../domain/live/ride_format.dart';
import '../../domain/stats/ride_stats.dart';
import '../../domain/stats/ride_stats_tracker.dart';
import '../providers/ride_map_providers.dart';
import '../ride_map_controller.dart';
import '../providers/rider_stats_providers.dart';

/// The frosted card shown when a rider taps another rider's dot.
///
/// Leads with who it is (avatar and name) and how fast they are going right
/// now. Beneath: which way they are heading, how far they are from this rider
/// right now and whether ahead or behind, and how good their connection is.
/// The rider's colour edges the card thinly, tying it to the dot it belongs
/// to.
///
/// It arrives in stages: the speed counts up from zero, then the distance
/// fades in, then the connection badge springs in. Everything after that
/// updates live, easing from one reading to the next.
class RiderInfoCard extends ConsumerStatefulWidget {
  const RiderInfoCard({super.key, required this.roomCode, required this.uid});

  final String roomCode;
  final String uid;

  static const double width = 244;

  @override
  ConsumerState<RiderInfoCard> createState() => _RiderInfoCardState();
}

class _RiderInfoCardState extends ConsumerState<RiderInfoCard>
    with SingleTickerProviderStateMixin {
  static const double _kmhPerMps = 3.6;
  static const double _speedSize = 44;

  /// The card's staged entrance, 0 to 1.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.springDuration + AppMotion.normal,
  )..forward();

  late final Animation<double> _count = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0, 0.6, curve: AppMotion.curve),
  );
  late final Animation<double> _distance = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.3, 0.75, curve: AppMotion.curve),
  );
  late final Animation<double> _badge = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.5, 1, curve: AppMotion.spring),
  );
  late final Animation<double> _badgeFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.5, 0.8, curve: AppMotion.curve),
  );

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Where [rider] is relative to this rider, from both riders' live GPS
  /// positions; `null` until this rider has a fix.
  ///
  /// Progression is this rider's live distance covered against the other
  /// rider's last saved distance, projected forward at their current speed to
  /// cover the time since it was saved.
  static RelativePosition? _relativeTo(
    RideMapState map,
    LiveRider rider,
    RideStats? theirs,
  ) {
    final me = map.myFix;
    if (me == null) return null;
    final theirProgress = theirs == null
        ? null
        : RelativePosition.projectProgress(
            savedMeters: theirs.distanceMeters,
            savedAtMs: theirs.lastSampleAtMs,
            speedMps: rider.speedMps,
            nowMs: DateTime.now().millisecondsSinceEpoch,
          );
    final moving = (me.speedMps ?? 0) >= RideStatsTracker.movingSpeedMps;
    return RelativePosition.between(
      me: me.point,
      other: rider.point,
      myProgressMeters: map.myStats?.distanceMeters,
      theirProgressMeters: theirProgress,
      myHeadingDegrees: moving ? me.headingDegrees : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomCode = widget.roomCode;
    final uid = widget.uid;
    final map = ref.watch(rideMapControllerProvider(roomCode));
    final rider = map.riders[uid];
    if (rider == null) return const SizedBox.shrink();
    final allStats = ref.watch(roomRideStatsProvider(roomCode)).value;
    final relative = _relativeTo(map, rider, allStats?[uid]);

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
      width: RiderInfoCard.width,
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
                // Shrinks to fit rather than overflowing beside the dial,
                // even at three-digit speeds.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // Counts up from zero as the card opens, then eases
                        // smoothly from one reading to the next.
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: speedKmh.toDouble()),
                          duration: AppMotion.normal,
                          curve: AppMotion.curve,
                          builder: (context, value, _) => AnimatedBuilder(
                            animation: _count,
                            builder: (context, _) => Text(
                              '${(value * _count.value).round()}',
                              style: AppTypography.stat(fontSize: _speedSize),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('km/h', style: theme.textTheme.bodySmall),
                      ],
                    ),
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
                  child: FadeTransition(
                    opacity: _distance,
                    child: SlideTransition(
                      position: _distance.drive(
                        Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ),
                      ),
                      child: _RelativeDistance(relative: relative),
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: _badge,
                  child: FadeTransition(
                    opacity: _badgeFade,
                    child: _QualityBadge(quality: quality),
                  ),
                ),
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
class _Heading extends StatefulWidget {
  const _Heading({required this.degrees});

  final double? degrees;

  @override
  State<_Heading> createState() => _HeadingState();
}

class _HeadingState extends State<_Heading> {
  static const double _dial = 40;

  /// The heading without wrap-around, so the arrow always turns the short way
  /// (350° to 10° passes through north instead of spinning back round).
  double? _unwrapped;

  @override
  void didUpdateWidget(_Heading oldWidget) {
    super.didUpdateWidget(oldWidget);
    _track(widget.degrees);
  }

  void _track(double? degrees) {
    if (degrees == null) return;
    final last = _unwrapped;
    if (last == null) {
      _unwrapped = degrees;
      return;
    }
    final delta = ((degrees - last % 360) + 540) % 360 - 180;
    _unwrapped = last + delta;
  }

  @override
  Widget build(BuildContext context) {
    final heading = widget.degrees;
    if (_unwrapped == null) _track(heading);
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
                    tween: Tween<double>(end: _unwrapped ?? heading),
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

/// "48 m" over "ahead": how far the rider is from this one right now. The
/// number eases between readings and the direction word cross-fades when it
/// changes, so a live update never flickers.
class _RelativeDistance extends StatelessWidget {
  const _RelativeDistance({required this.relative});

  /// `null` until this rider has a GPS fix of their own.
  final RelativePosition? relative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = relative;
    final caption = theme.textTheme.labelSmall?.copyWith(
      color: value?.direction == RelativeDirection.unknown || value == null
          ? AppColors.textTertiary
          : AppColors.primary,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      label: value == null ? 'Distance unknown' : value.label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (value == null)
            Text(
              '—',
              style: AppTypography.stat(fontSize: AppTypeScale.statSmall),
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: value.meters),
              duration: AppMotion.slow,
              curve: AppMotion.curve,
              builder: (context, meters, _) => Text(
                RideFormat.distance(meters),
                style: AppTypography.stat(fontSize: AppTypeScale.statSmall),
              ),
            ),
          AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.exit,
            child: Text(
              value?.directionLabel ?? 'locating you',
              key: ValueKey(value?.direction),
              style: caption,
            ),
          ),
        ],
      ),
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
