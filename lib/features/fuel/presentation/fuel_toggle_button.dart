import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/pressable_scale.dart';
import 'fuel_info_sheet.dart';
import 'fuel_layer_preference.dart';

/// The ride map's fuel controls: the Fuel button, which a single tap turns
/// on or off, and a small ⓘ button beside it that opens the fuel
/// information (legend, stations loaded, last updated). No hidden gestures.
///
/// Fuel on: filled purple with a white pump. Off: the dark map-button glass
/// with a grey pump. Until the saved choice has been read both keep their
/// place but stay invisible, so nothing flips from one look to the other on
/// open.
class FuelControls extends ConsumerWidget {
  const FuelControls({super.key});

  static const double size = 44;
  static const double infoSize = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(fuelLayerVisibleProvider);
    if (on == null) {
      return const SizedBox(
        width: size + AppSpacing.sm + infoSize,
        height: size,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          size: infoSize,
          label: 'Fuel information',
          onTap: () {
            AppHaptics.selection();
            showFuelInfoSheet(context);
          },
          child: const Icon(
            Icons.info_outline_rounded,
            size: AppIconSize.small,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _RoundButton(
          size: size,
          label: on ? 'Fuel stations on' : 'Fuel stations off',
          toggled: on,
          filled: on,
          onTap: () {
            AppHaptics.selection();
            ref.read(fuelLayerVisibleProvider.notifier).setVisible(!on);
          },
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              end: on ? Colors.white : AppColors.textTertiary,
            ),
            duration: AppMotion.normal,
            builder: (context, color, _) => Icon(
              Icons.local_gas_station_rounded,
              size: AppIconSize.medium,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// A round map button: dark glass, or filled purple when [filled]. Tap only.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.label,
    required this.onTap,
    required this.child,
    this.toggled,
    this.filled = false,
  });

  final double size;
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool? toggled;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: toggled,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GlassPanel(
                  padding: EdgeInsets.zero,
                  radius: size,
                  child: const SizedBox.expand(),
                ),
                AnimatedContainer(
                  duration: AppMotion.normal,
                  curve: AppMotion.curve,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.transparent,
                  ),
                ),
                Center(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
