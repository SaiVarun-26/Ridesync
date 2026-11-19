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

/// The ride map's fuel control: one tap shows or hides fuel stations; a long
/// press opens the fuel information (the legend, how many are loaded, when
/// they were last updated).
///
/// On: filled purple with a white pump. Off: the dark map-button glass with
/// a grey pump. Until the saved choice has been read it takes its place but
/// stays invisible, so it never flips from one look to the other on open.
class FuelToggleButton extends ConsumerWidget {
  const FuelToggleButton({super.key});

  static const double size = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(fuelLayerVisibleProvider);
    if (on == null) return const SizedBox.square(dimension: size);
    return Semantics(
      button: true,
      toggled: on,
      label: 'Fuel stations',
      hint: on ? 'Double tap to hide' : 'Double tap to show',
      onLongPressHint: 'Fuel information',
      excludeSemantics: true,
      child: PressableScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            AppHaptics.selection();
            ref.read(fuelLayerVisibleProvider.notifier).setVisible(!on);
          },
          onLongPress: () {
            AppHaptics.light();
            showFuelInfoSheet(context);
          },
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const GlassPanel(
                  padding: EdgeInsets.zero,
                  radius: size,
                  child: SizedBox.expand(),
                ),
                AnimatedContainer(
                  duration: AppMotion.normal,
                  curve: AppMotion.curve,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? AppColors.primary : Colors.transparent,
                  ),
                ),
                Center(
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
            ),
          ),
        ),
      ),
    );
  }
}
