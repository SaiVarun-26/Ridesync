import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon.dart';

/// When the [index]th card of a story starts its entrance.
Duration storyDelay(int index) =>
    Duration(milliseconds: 80 + index * 90);

/// One card of a ride's story: a solid surface with a small labelled header,
/// that rises, fades and settles into place a beat after the card before it.
class FlexCard extends StatelessWidget {
  const FlexCard({
    super.key,
    required this.index,
    required this.child,
    this.label,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.accent,
  });

  /// The card's place in the story, for the stagger.
  final int index;
  final Widget child;

  /// The small header ("PERFORMANCE"), with an optional [icon].
  final String? label;
  final IconData? icon;

  /// A control at the end of the header.
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// Edges the card in a colour (the rider's, the brand's).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final delay = storyDelay(index);
    final total = delay + AppMotion.entrance;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1),
      builder: (context, p, child) {
        final t = AppMotion.curve.transform(p);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: Transform.scale(
              scale: 0.97 + 0.03 * AppMotion.spring.transform(p),
              child: child,
            ),
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: accent?.withValues(alpha: 0.5) ?? AppColors.border,
          ),
        ),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null) ...[
                CardLabel(label: label!, icon: icon, trailing: trailing),
                const SizedBox(height: AppSpacing.lg),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// The small header of a [FlexCard].
class CardLabel extends StatelessWidget {
  const CardLabel({super.key, required this.label, this.icon, this.trailing});

  final String label;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppIconSize.small, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A number that counts up to [value] once it appears, after [delay].
class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String Function(double value) format;
  final TextStyle style;
  final Duration delay;
  final Duration duration;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.curve,
  );
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _start?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) =>
          Text(widget.format(widget.value * _curve.value), style: widget.style),
    );
  }
}

/// A figure with its unit and a small label beneath: the way every number in
/// a story is shown.
class StoryStat extends StatelessWidget {
  const StoryStat({
    super.key,
    required this.value,
    required this.format,
    required this.label,
    this.unit,
    this.size = 22,
    this.delay = Duration.zero,
    this.color = AppColors.textPrimary,
  });

  final double value;
  final String Function(double value) format;
  final String label;
  final String? unit;
  final double size;
  final Duration delay;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              CountUp(
                value: value,
                format: format,
                delay: delay,
                style: AppTypography.stat(fontSize: size, color: color),
              ),
              if (unit != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  unit!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.1,
            fontSize: AppTypeScale.micro,
          ),
        ),
      ],
    );
  }
}

/// "24.3" for 24.3 km, "850" for 850 m, with [distanceUnit] saying which.
String distanceFigure(double meters) => meters < 1000
    ? '${meters.round()}'
    : meters >= 10000
    ? (meters / 1000).toStringAsFixed(meters >= 100000 ? 0 : 1)
    : (meters / 1000).toStringAsFixed(2);

String distanceUnit(double meters) => meters < 1000 ? 'm' : 'km';

/// "46" for a speed in km/h.
String speedFigure(double mps) => '${(mps * 3.6).round()}';

/// "1:12:04" or "42:10".
String durationFigure(Duration value) {
  final total = value.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
