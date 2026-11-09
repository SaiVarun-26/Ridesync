import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glow_button.dart';
import '../../domain/room.dart';
import '../../domain/room_member.dart';

/// The lobby's bottom action area.
///
/// The host sees the live ready count and a Continue button that stays
/// disabled until every rider is ready. Every other rider sees a Ready toggle.
/// Anchored to the bottom so the primary action is always in thumb reach.
class LobbyActionBar extends StatelessWidget {
  const LobbyActionBar({
    super.key,
    required this.room,
    required this.me,
    required this.isBusy,
    required this.onToggleReady,
    required this.onContinue,
  });

  final Room room;

  /// The current rider, or `null` if they are no longer a member.
  final RoomMember? me;

  /// Whether a ready/continue request is in flight.
  final bool isBusy;

  final VoidCallback onToggleReady;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final rider = me;
    if (rider == null) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: rider.isHost
              ? _HostControls(room: room, isBusy: isBusy, onContinue: onContinue)
              : _RiderControls(
                  rider: rider,
                  isBusy: isBusy,
                  onToggleReady: onToggleReady,
                ),
        ),
      ),
    );
  }
}

class _HostControls extends StatelessWidget {
  const _HostControls({
    required this.room,
    required this.isBusy,
    required this.onContinue,
  });

  final Room room;
  final bool isBusy;
  final VoidCallback onContinue;

  static const double _countSize = 22;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hostHasColor = room.host?.hasColor ?? false;
    final hint = !hostHasColor
        ? 'Pick your color to continue.'
        : room.everyoneReady
            ? 'Everyone is ready.'
            : 'Waiting for every rider to be ready.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.normal,
              child: Text(
                '${room.readyCount} / ${room.members.length}',
                key: ValueKey<String>(
                  '${room.readyCount}/${room.members.length}',
                ),
                style: AppTypography.stat(fontSize: _countSize),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Riders Ready', style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _Hint(text: hint),
        const SizedBox(height: AppSpacing.lg),
        GlowButton(
          label: 'Continue →',
          isLoading: isBusy,
          onPressed: room.canContinue ? onContinue : null,
        ),
      ],
    );
  }
}

class _RiderControls extends StatelessWidget {
  const _RiderControls({
    required this.rider,
    required this.isBusy,
    required this.onToggleReady,
  });

  final RoomMember rider;
  final bool isBusy;
  final VoidCallback onToggleReady;

  @override
  Widget build(BuildContext context) {
    final String hint;
    if (!rider.hasColor) {
      hint = 'Pick your color, then tap Ready.';
    } else if (rider.isReady) {
      hint = 'You’re ready. The host will start the ride.';
    } else {
      hint = 'Tap Ready when you’re set to ride.';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hint(text: hint),
        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: AppMotion.normal,
          switchInCurve: AppMotion.curve,
          switchOutCurve: AppMotion.curve,
          child: rider.isReady
              ? GlowButton(
                  key: const ValueKey<bool>(true),
                  label: '✓ Ready',
                  variant: GlowButtonVariant.secondary,
                  isLoading: isBusy,
                  onPressed: onToggleReady,
                )
              : GlowButton(
                  key: const ValueKey<bool>(false),
                  label: 'Ready',
                  isLoading: isBusy,
                  onPressed: rider.hasColor ? onToggleReady : null,
                ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}
