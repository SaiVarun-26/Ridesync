import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pulse_indicator.dart';
import '../../../../core/widgets/section_label.dart';
import '../../domain/route_model.dart';
import '../route_formatting.dart';

/// The chosen destination with its distance and riding time.
///
/// Every change (a new destination, or a route being generated) crossfades
/// with a slight scale and an Electric Blue glow, and the card floats very
/// gently while shown.
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.route,
    required this.pendingDestination,
  });

  /// The shared route, if one has been generated.
  final PlannedRoute? route;

  /// Name of a destination whose route is being generated right now.
  final String? pendingDestination;

  @override
  Widget build(BuildContext context) {
    final pending = pendingDestination;
    final current = route;

    final Widget content;
    final Object key;
    if (pending != null) {
      key = 'pending:$pending';
      content = _GeneratingContent(destination: pending);
    } else if (current != null) {
      key = 'route:${current.destinationName}:${current.createdAt}';
      content = _RouteContent(route: current);
    } else {
      key = 'empty';
      content = const _EmptyContent();
    }

    return _Floating(
      child: AnimatedSwitcher(
        duration: AppMotion.slow,
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.curve,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: _CardFrame(
          key: ValueKey<Object>(key),
          glowing: current != null || pending != null,
          child: content,
        ),
      ),
    );
  }
}

class _RouteContent extends StatelessWidget {
  const _RouteContent({required this.route});

  final PlannedRoute route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('DESTINATION'),
        const SizedBox(height: AppSpacing.md),
        Text(
          route.destinationName,
          style: theme.textTheme.headlineSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (route.destinationAddress.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            route.destinationAddress,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'DISTANCE',
                value: RouteFormatting.distance(route.distanceMeters),
              ),
            ),
            Expanded(
              child: _Stat(
                label: 'ETA',
                value: RouteFormatting.duration(route.durationSeconds),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GeneratingContent extends StatelessWidget {
  const _GeneratingContent({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('DESTINATION'),
        const SizedBox(height: AppSpacing.md),
        Text(destination, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const PulseIndicator(),
            const SizedBox(width: AppSpacing.md),
            Text('Generating route…', style: theme.textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('DESTINATION'),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No destination yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  static const double _valueSize = 22;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTypography.stat(fontSize: _valueSize)),
      ],
    );
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({super.key, required this.glowing, required this.child});

  final bool glowing;
  final Widget child;

  static const double _glowAlpha = 0.22;
  static const double _glowBlur = 36;
  static const double _glowSpread = -10;
  static const double _borderAlpha = 0.45;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: glowing
              ? AppColors.route.withValues(alpha: _borderAlpha)
              : AppColors.divider,
        ),
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: AppColors.route.withValues(alpha: _glowAlpha),
                  blurRadius: _glowBlur,
                  spreadRadius: _glowSpread,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Drifts its child up and down by a few pixels, very slowly.
class _Floating extends StatefulWidget {
  const _Floating({required this.child});

  final Widget child;

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating>
    with SingleTickerProviderStateMixin {
  static const Duration _halfPeriod = Duration(seconds: 3);
  static const double _amplitude = 3;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _halfPeriod)
        ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, (t - 0.5) * 2 * _amplitude),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
