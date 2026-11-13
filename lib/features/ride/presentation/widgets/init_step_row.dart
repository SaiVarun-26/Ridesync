import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/pulse_indicator.dart';
import '../../../../core/widgets/ride_loader.dart';
import '../../domain/initialization/init_task.dart';
import '../../domain/initialization/ride_initializer.dart';

/// One initialization step: a status indicator, its label, and any waiting
/// message.
///
/// The indicator morphs between states with a scale-and-fade, and a finished
/// step lands on a solid success-green check.
class InitStepRow extends StatelessWidget {
  const InitStepRow({super.key, required this.step});

  final InitStepState step;

  static const double _indicatorSlot = 22;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = step.phase == InitStepPhase.pending
        ? AppColors.textTertiary
        : AppColors.textPrimary;
    final message = step.message;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _indicatorSlot,
          height: _indicatorSlot,
          child: AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: AppMotion.spring,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: _Indicator(
              key: ValueKey<InitStepPhase>(step.phase),
              phase: step.phase,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                style: (theme.textTheme.titleMedium ?? const TextStyle())
                    .copyWith(color: labelColor),
                child: Text(step.label),
              ),
              AnimatedSize(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                alignment: Alignment.topLeft,
                child: message == null || step.phase != InitStepPhase.waiting
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({super.key, required this.phase});

  final InitStepPhase phase;

  static const double _pendingSize = 8;
  static const double _ringWidth = 1.5;
  static const double _spinnerSize = 14;
  static const double _waitingSize = 8;
  static const double _checkSize = 20;
  static const double _checkIconSize = 13;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: switch (phase) {
        InitStepPhase.pending => Container(
          width: _pendingSize,
          height: _pendingSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textTertiary,
              width: _ringWidth,
            ),
          ),
        ),
        InitStepPhase.running => const RideLoader(size: _spinnerSize),
        InitStepPhase.waiting => const PulseIndicator(size: _waitingSize),
        InitStepPhase.blocked => const PulseIndicator(
          size: _waitingSize,
          color: AppColors.error,
        ),
        InitStepPhase.done => Container(
          width: _checkSize,
          height: _checkSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: _checkIconSize,
            color: AppColors.textPrimary,
          ),
        ),
      },
    );
  }
}
