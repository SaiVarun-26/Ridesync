import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/glow_button.dart';
import '../../domain/completion/ride_end_stage.dart';

/// Full-screen wrap-up shown while a ride ends: three steps that tick off as
/// the work gets done, ending on all three before the results open.
///
/// If the host's ending fails, the active step turns into an error with a
/// retry, so the ride is never left half-ended without a way forward.
class RideEndingOverlay extends StatelessWidget {
  const RideEndingOverlay({
    super.key,
    required this.stage,
    this.error,
    this.onRetry,
    this.onDismiss,
  });

  final RideEndStage stage;

  /// When set, ending failed and this explains why.
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  static const List<String> _steps = [
    'Ending Ride...',
    'Saving rider data...',
    'Generating ride summary...',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = error != null;
    // Index of the step being worked on; past the last once complete.
    final active = stage.index;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: ColoredBox(
          color: AppColors.background.withValues(alpha: 0.9),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: BrandMark(breathing: !failed)),
                    const SizedBox(height: AppSpacing.xxl),
                    Center(
                      child: AnimatedSwitcher(
                        duration: AppMotion.normal,
                        child: Text(
                          failed
                              ? 'Could not end the ride'
                              : stage == RideEndStage.complete
                              ? 'Ride complete'
                              : 'Wrapping up your ride',
                          key: ValueKey(
                            failed ? 'failed' : stage == RideEndStage.complete,
                          ),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    for (var i = 0; i < _steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.lg),
                      _StepRow(
                        label: _steps[i],
                        state: i < active
                            ? _StepState.done
                            : i == active
                            ? (failed ? _StepState.failed : _StepState.active)
                            : _StepState.pending,
                      ),
                    ],
                    if (failed) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (onRetry != null)
                        GlowButton(label: 'Try again', onPressed: onRetry),
                      if (onDismiss != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        GlowButton(
                          label: 'Back to ride',
                          variant: GlowButtonVariant.secondary,
                          onPressed: onDismiss,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StepState { pending, active, done, failed }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = switch (state) {
      _StepState.pending => AppColors.textTertiary,
      _StepState.active => AppColors.textPrimary,
      _StepState.done => AppColors.textSecondary,
      _StepState.failed => AppColors.warning,
    };
    return Row(
      children: [
        SizedBox(
          width: _iconSize,
          height: _iconSize,
          child: AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: switch (state) {
              _StepState.done => const Icon(
                Icons.check_circle,
                key: ValueKey('done'),
                size: _iconSize,
                color: AppColors.neonGreen,
              ),
              _StepState.active => const Padding(
                key: ValueKey('active'),
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.neonGreen,
                ),
              ),
              _StepState.failed => const Icon(
                Icons.error_outline,
                key: ValueKey('failed'),
                size: _iconSize,
                color: AppColors.warning,
              ),
              _StepState.pending => const Icon(
                Icons.circle_outlined,
                key: ValueKey('pending'),
                size: _iconSize,
                color: AppColors.textTertiary,
              ),
            },
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Flexible(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.normal,
            style: theme.textTheme.titleMedium!.copyWith(color: textColor),
            child: Text(label),
          ),
        ),
      ],
    );
  }
}
