import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/rider_palette.dart';
import 'color_tile.dart';

/// Inline color picker: the featured colors followed by a "+" tile that opens
/// the full palette.
class RiderColorPicker extends StatelessWidget {
  const RiderColorPicker({
    super.key,
    required this.claimedByOthers,
    required this.mySelection,
    required this.enabled,
    required this.onSelected,
    required this.onMore,
  });

  /// Color ids held by other riders (shown disabled).
  final Set<String> claimedByOthers;

  /// The current rider's color id, if any.
  final String? mySelection;

  /// Whether the rider may change color right now.
  final bool enabled;

  /// Called with the id of a tapped, available featured color.
  final ValueChanged<String> onSelected;

  /// Opens the full color sheet.
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final extendedSelection = RiderPalette.isFeatured(mySelection)
        ? null
        : RiderPalette.colorById(mySelection)?.color;

    return Row(
      spacing: AppSpacing.md,
      children: [
        for (final c in RiderPalette.featured)
          Expanded(
            child: ColorTile(
              color: c.color,
              label: c.label,
              state: colorTileStateFor(
                id: c.id,
                mySelection: mySelection,
                claimedByOthers: claimedByOthers,
              ),
              onTap: enabled ? () => onSelected(c.id) : null,
            ),
          ),
        Expanded(
          child: MoreColorsTile(
            selectedExtendedColor: extendedSelection,
            onTap: enabled ? onMore : null,
          ),
        ),
      ],
    );
  }
}

/// Resolves how color [id] should render for the current rider.
ColorTileState colorTileStateFor({
  required String id,
  required String? mySelection,
  required Set<String> claimedByOthers,
}) {
  if (id == mySelection) return ColorTileState.mine;
  if (claimedByOthers.contains(id)) return ColorTileState.taken;
  return ColorTileState.available;
}
