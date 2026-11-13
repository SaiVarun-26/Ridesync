import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/rider_dot.dart';

/// How a color appears to the current rider.
enum ColorTileState {
  /// Free to claim.
  available,

  /// Claimed by the current rider.
  mine,

  /// Claimed by another rider; disabled.
  taken,
}

/// A square tile showing one rider color as a dot.
///
/// The current rider's color is ringed and glows; colors held by others are
/// dimmed and disabled. Presentation only: claiming happens in the repository.
class ColorTile extends StatelessWidget {
  const ColorTile({
    super.key,
    required this.color,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final Color color;

  /// Color name, used for accessibility.
  final String label;

  final ColorTileState state;

  /// Called when an available tile is tapped. `null` disables the tile.
  final VoidCallback? onTap;

  /// Dot opacity for a color held by another rider.
  static const double _takenAlpha = 0.22;

  @override
  Widget build(BuildContext context) {
    final taken = state == ColorTileState.taken;
    final mine = state == ColorTileState.mine;
    return Semantics(
      button: true,
      label: taken ? '$label, taken' : label,
      selected: mine,
      enabled: !taken && onTap != null,
      child: _TileFrame(
        accent: mine ? color : null,
        onTap: taken ? null : onTap,
        child: RiderDot(
          color: taken ? color.withValues(alpha: _takenAlpha) : color,
          size: _TileFrame.dotSize,
        ),
      ),
    );
  }
}

/// The trailing "+" tile that opens the full color sheet.
///
/// When the current rider holds a color from the extended palette, the tile
/// shows that color (ringed) so their choice stays visible in the inline row.
class MoreColorsTile extends StatelessWidget {
  const MoreColorsTile({
    super.key,
    required this.selectedExtendedColor,
    required this.onTap,
  });

  /// The rider's color when it is not one of the featured colors.
  final Color? selectedExtendedColor;

  /// Opens the color sheet. `null` disables the tile.
  final VoidCallback? onTap;

  /// Size of the "+" badge drawn over a selected extended color.
  static const double _badgeIconSize = 12;

  @override
  Widget build(BuildContext context) {
    final selected = selectedExtendedColor;
    return Semantics(
      button: true,
      label: 'More colors',
      enabled: onTap != null,
      child: _TileFrame(
        accent: selected,
        onTap: onTap,
        child: selected == null
            ? const Icon(Icons.add_rounded, color: AppColors.textSecondary)
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  RiderDot(color: selected, size: _TileFrame.dotSize),
                  const Positioned(
                    right: -AppSpacing.md,
                    top: -AppSpacing.md,
                    child: Icon(
                      Icons.add_rounded,
                      size: _badgeIconSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Shared square frame for color tiles: dark surface, hairline border, and a
/// ring plus soft glow in [accent] when selected.
class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.accent,
    required this.onTap,
    required this.child,
  });

  /// Diameter of the color dot inside a tile.
  static const double dotSize = 20;

  static const double _selectedBorderWidth = 2;

  final Color? accent;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selected = accent;
    final radius = BorderRadius.circular(AppRadius.md);
    return AspectRatio(
      aspectRatio: 1,
      child: PressableScale(
        enabled: onTap != null,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: radius,
            border: Border.all(
              color: selected ?? AppColors.border,
              width: selected == null ? 1 : _selectedBorderWidth,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
