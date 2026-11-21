import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import 'auto_end_controller.dart';

/// The auto-end question: a light sheet at the bottom of the map asking
/// whether the ride is over, counting down to ending it.
///
/// Three answers: Continue Ride, Pause Ride, End Ride Now. The countdown
/// runs smoothly from the prompt's deadline; the sheet goes away by itself if
/// the rider moves (the controller clears the prompt).
class AutoEndSheet extends StatefulWidget {
  const AutoEndSheet({
    super.key,
    required this.prompt,
    required this.onContinue,
    required this.onPause,
    required this.onEnd,
  });

  final AutoEndPrompt prompt;
  final VoidCallback onContinue;
  final VoidCallback onPause;
  final VoidCallback onEnd;

  @override
  State<AutoEndSheet> createState() => _AutoEndSheetState();
}

class _AutoEndSheetState extends State<AutoEndSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: AutoEndSettings.countdown,
  );

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(AutoEndSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prompt.id != widget.prompt.id) _start();
  }

  /// Runs from however much of the countdown is left.
  void _start() {
    final total = AutoEndSettings.countdown.inMilliseconds;
    final left = widget.prompt.deadlineMs - DateTime.now().millisecondsSinceEpoch;
    _countdown
      ..value = (1 - left / total).clamp(0.0, 1.0)
      ..forward();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = AutoEndSettings.countdown.inSeconds;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.lifted,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _countdown,
                  builder: (context, _) => _Ring(
                    progress: _countdown.value,
                    seconds: math.max(
                      0,
                      (total * (1 - _countdown.value)).ceil(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Looks like you've stopped riding.",
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Would you like to end your ride?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedBuilder(
              animation: _countdown,
              builder: (context, _) {
                final left = math.max(0, (total * (1 - _countdown.value)).ceil());
                return Text(
                  'Automatically ending in $left '
                  '${left == 1 ? 'second' : 'seconds'}...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Continue Ride',
              icon: Icons.play_arrow_rounded,
              verticalPadding: AppSpacing.md,
              onPressed: widget.onContinue,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Pause Ride',
                    icon: Icons.pause_rounded,
                    variant: AppButtonVariant.secondary,
                    verticalPadding: AppSpacing.md,
                    onPressed: widget.onPause,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'End Ride Now',
                    icon: Icons.stop_rounded,
                    variant: AppButtonVariant.destructive,
                    verticalPadding: AppSpacing.md,
                    onPressed: widget.onEnd,
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

/// The countdown: a ring emptying smoothly, with the seconds left inside.
class _Ring extends StatelessWidget {
  const _Ring({required this.progress, required this.seconds});

  final double progress;
  final int seconds;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: CustomPaint(
        painter: _RingPainter(progress),
        child: Center(
          child: Text('$seconds', style: AppTypography.stat(fontSize: 20)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas
      ..drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = AppColors.border,
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * (1 - progress),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
