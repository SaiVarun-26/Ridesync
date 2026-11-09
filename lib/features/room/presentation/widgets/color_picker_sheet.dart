import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/rider_palette.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/room_providers.dart';
import 'color_tile.dart';
import 'rider_color_picker.dart';

/// Claims a color and returns an error message, or `null` on success.
typedef ColorClaimCallback = Future<String?> Function(String colorId);

/// Opens the full rider palette as a modal bottom sheet for room [roomCode].
///
/// The sheet watches the live room, so colors claimed by others disable while
/// it is open. It closes once a claim succeeds; failures are shown inside the
/// sheet, where a SnackBar would be hidden behind the modal barrier.
Future<void> showColorPickerSheet({
  required BuildContext context,
  required String roomCode,
  required ColorClaimCallback onClaim,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _ColorPickerSheet(roomCode: roomCode, onClaim: onClaim),
  );
}

class _ColorPickerSheet extends ConsumerStatefulWidget {
  const _ColorPickerSheet({required this.roomCode, required this.onClaim});

  final String roomCode;
  final ColorClaimCallback onClaim;

  @override
  ConsumerState<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends ConsumerState<_ColorPickerSheet> {
  bool _isClaiming = false;
  String? _error;

  static const int _columns = 4;

  /// Caps the sheet height so the lobby stays visible behind it.
  static const double _maxHeightFraction = 0.8;

  Future<void> _claim(String colorId) async {
    if (_isClaiming) return;
    setState(() {
      _isClaiming = true;
      _error = null;
    });
    final error = await widget.onClaim(colorId);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isClaiming = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final room = ref.watch(roomStreamProvider(widget.roomCode)).value;
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    final mySelection = myUid == null ? null : room?.memberByUid(myUid)?.colorId;
    final claimedByOthers = room?.colorsClaimedByOthers(myUid) ?? <String>{};

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _maxHeightFraction,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your color', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your color is how your group sees you on the road.',
                style: theme.textTheme.bodyMedium,
              ),
              AnimatedSize(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Flexible(
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: _columns,
                  mainAxisSpacing: AppSpacing.lg,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.78,
                  children: [
                    for (final c in RiderPalette.colors)
                      _LabeledColorTile(
                        color: c,
                        state: colorTileStateFor(
                          id: c.id,
                          mySelection: mySelection,
                          claimedByOthers: claimedByOthers,
                        ),
                        onTap: _isClaiming ? null : () => _claim(c.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledColorTile extends StatelessWidget {
  const _LabeledColorTile({
    required this.color,
    required this.state,
    required this.onTap,
  });

  final RiderColor color;
  final ColorTileState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final taken = state == ColorTileState.taken;
    return Column(
      children: [
        ColorTile(
          color: color.color,
          label: color.label,
          state: state,
          onTap: onTap,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          color.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: taken ? AppColors.textTertiary : AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
