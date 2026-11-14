import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/section_label.dart';
import '../../domain/live/ride_format.dart';
import '../ride_map_controller.dart';
import 'ride_map_overlays.dart';
import 'slide_to_confirm.dart';

/// The bottom panel of the live map.
///
/// Collapsed it is the speed and status row, taking the same room it always
/// has, so the map stays clear. Tapping or dragging the handle opens it to
/// show the ride's duration, distance and riders, moving and stopped time and
/// average moving speed, and, for the host, the
/// slide that ends the ride. Ending the ride lives here rather than floating
/// over the map.
class RideControlPanel extends StatefulWidget {
  const RideControlPanel({
    super.key,
    required this.speedKmh,
    required this.isConnected,
    required this.gps,
    required this.duration,
    required this.distanceMeters,
    required this.riderCount,
    required this.isHost,
    required this.canEnd,
    required this.isEnding,
    required this.onEndRide,
    this.movingTime = Duration.zero,
    this.stoppedTime = Duration.zero,
    this.averageSpeedMps = 0,
  });

  /// Time spent actually moving, and time spent stopped, so far.
  final Duration movingTime;
  final Duration stoppedTime;

  /// Average speed while moving (stops excluded).
  final double averageSpeedMps;

  final double speedKmh;
  final bool isConnected;
  final GpsStatus gps;

  /// Time since this rider's ride started.
  final Duration duration;
  final double distanceMeters;
  final int riderCount;

  final bool isHost;

  /// Whether the ride can be ended right now (host, ride in progress).
  final bool canEnd;

  /// Whether ending the ride is in progress.
  final bool isEnding;
  final VoidCallback onEndRide;

  @override
  State<RideControlPanel> createState() => _RideControlPanelState();
}

class _RideControlPanelState extends State<RideControlPanel> {
  bool _expanded = false;

  /// A vertical fling faster than this opens or closes the panel.
  static const double _flingVelocity = 150;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _onHandleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -_flingVelocity && !_expanded) {
      setState(() => _expanded = true);
    } else if (velocity > _flingVelocity && _expanded) {
      setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Handle(
            expanded: _expanded,
            onTap: _toggle,
            onDragEnd: _onHandleDragEnd,
          ),
          RideStatusRow(
            speedKmh: widget.speedKmh,
            isConnected: widget.isConnected,
            gps: widget.gps,
          ),
          AnimatedSize(
            duration: AppMotion.slow,
            curve: AppMotion.curve,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _Details(
                    duration: widget.duration,
                    movingTime: widget.movingTime,
                    stoppedTime: widget.stoppedTime,
                    averageSpeedMps: widget.averageSpeedMps,
                    distanceMeters: widget.distanceMeters,
                    riderCount: widget.riderCount,
                    isHost: widget.isHost,
                    canEnd: widget.canEnd,
                    isEnding: widget.isEnding,
                    onEndRide: widget.onEndRide,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.expanded,
    required this.onTap,
    required this.onDragEnd,
  });

  final bool expanded;
  final VoidCallback onTap;
  final GestureDragEndCallback onDragEnd;

  static const double _barWidth = 36;
  static const double _barHeight = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: expanded ? 'Close ride panel' : 'Open ride panel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onVerticalDragEnd: onDragEnd,
        child: SizedBox(
          height: 28,
          child: Center(
            child: Container(
              width: _barWidth,
              height: _barHeight,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.duration,
    required this.movingTime,
    required this.stoppedTime,
    required this.averageSpeedMps,
    required this.distanceMeters,
    required this.riderCount,
    required this.isHost,
    required this.canEnd,
    required this.isEnding,
    required this.onEndRide,
  });

  final Duration duration;
  final Duration movingTime;
  final Duration stoppedTime;
  final double averageSpeedMps;
  final double distanceMeters;
  final int riderCount;
  final bool isHost;
  final bool canEnd;
  final bool isEnding;
  final VoidCallback onEndRide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Figure(label: 'DURATION', value: RideFormat.duration(duration)),
              _Figure(
                label: 'DISTANCE',
                value: RideFormat.distance(distanceMeters),
              ),
              _Figure(label: 'RIDERS', value: '$riderCount'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Figure(label: 'MOVING', value: RideFormat.duration(movingTime)),
              _Figure(
                label: 'STOPPED',
                value: RideFormat.duration(stoppedTime),
              ),
              _Figure(
                label: 'AVG SPEED',
                value: RideFormat.speed(averageSpeedMps),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (canEnd)
            SlideToConfirm(
              label: 'Slide to End Ride',
              isBusy: isEnding,
              onConfirmed: onEndRide,
            )
          else if (!isHost)
            Text(
              'Only the host can end the ride.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  static const double _valueSize = 22;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTypography.stat(fontSize: _valueSize)),
          ),
          const SizedBox(height: AppSpacing.xs),
          SectionLabel(label),
        ],
      ),
    );
  }
}
