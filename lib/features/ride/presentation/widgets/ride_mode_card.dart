import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_label.dart';

/// A large, minimal card describing one ride type.
///
/// Black surface, hairline border, and an Electric Blue ring with a soft glow
/// when selected. Disabled cards (for riders waiting on the host) stay
/// readable but dimmed and do not respond to taps.
class RideModeCard extends StatelessWidget {
  const RideModeCard({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.selected,
    required this.onTap,
  });

  /// Small ordinal shown in the corner, e.g. "01".
  final String index;

  final String title;
  final String subtitle;

  /// Short descriptive lines shown as a list.
  final List<String> points;

  final bool selected;

  /// Selects the card. `null` renders the card disabled.
  final VoidCallback? onTap;

  static const double _disabledOpacity = 0.45;
  static const double _selectedBorderWidth = 1.5;
  static const double _glowAlpha = 0.28;
  static const double _glowBlur = 32;
  static const double _glowSpread = -8;
  static const double _pressedAlpha = 0.05;
  static const double _bulletSize = 4;
  static const double _markerSize = 10;
  static const double _markerGlowAlpha = 0.6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$title. $subtitle',
      child: AnimatedOpacity(
        duration: AppMotion.normal,
        opacity: enabled || selected ? 1 : _disabledOpacity,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.route : AppColors.divider,
              width: selected ? _selectedBorderWidth : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.route.withValues(alpha: _glowAlpha),
                      blurRadius: _glowBlur,
                      spreadRadius: _glowSpread,
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              splashColor: Colors.transparent,
              highlightColor: AppColors.route.withValues(alpha: _pressedAlpha),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SectionLabel(index),
                        const Spacer(),
                        AnimatedScale(
                          duration: AppMotion.normal,
                          curve: AppMotion.curve,
                          scale: selected ? 1 : 0,
                          child: Container(
                            width: _markerSize,
                            height: _markerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.route,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.route.withValues(
                                    alpha: _markerGlowAlpha,
                                  ),
                                  blurRadius: _markerSize,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (final point in points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Container(
                                width: _bulletSize,
                                height: _bulletSize,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                point,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
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
