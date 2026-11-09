import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/rider_palette.dart';
import '../../../../core/widgets/neon_card.dart';
import '../../../../core/widgets/rider_dot.dart';
import '../../domain/room_member.dart';

/// Lobby status of a rider, in display priority order.
enum _RiderStatus { host, ready, offline, waiting }

/// One rider in the lobby list: their color dot, name, and live status.
///
/// The card picks up a soft glow in the rider's color once they count as ready,
/// so a fully ready group visibly "lights up".
class RiderTile extends StatelessWidget {
  const RiderTile({super.key, required this.member, required this.isMe});

  final RoomMember member;
  final bool isMe;

  /// Fallback for riders who skipped the display name.
  static const String _fallbackName = 'Rider';

  static const double _dotSize = 14;

  _RiderStatus get _status {
    if (member.isHost) return _RiderStatus.host;
    if (member.isReady) return _RiderStatus.ready;
    if (!member.online) return _RiderStatus.offline;
    return _RiderStatus.waiting;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = RiderPalette.colorById(member.colorId)?.color;
    final trimmed = member.displayName?.trim() ?? '';
    final name = trimmed.isEmpty ? _fallbackName : trimmed;
    final lit = member.online && member.countsAsReady;

    return NeonCard(
      glowColor: lit ? color : null,
      child: Row(
        children: [
          RiderDot(color: color, size: _dotSize),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: name,
                children: [
                  if (isMe)
                    TextSpan(
                      text: '  You',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: member.online
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            child: _StatusLabel(
              key: ValueKey<_RiderStatus>(_status),
              status: _status,
              accent: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({super.key, required this.status, required this.accent});

  final _RiderStatus status;

  /// The rider's color, used for the ready check mark.
  final Color? accent;

  static const double _checkSize = 16;
  static const double _hostLetterSpacing = 1.6;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelMedium;
    return switch (status) {
      _RiderStatus.host => Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            'HOST',
            style: label?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: _hostLetterSpacing,
            ),
          ),
        ),
      _RiderStatus.ready => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              size: _checkSize,
              color: accent ?? AppColors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('Ready', style: label?.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      _RiderStatus.offline => Text(
          'Offline',
          style: label?.copyWith(color: AppColors.textTertiary),
        ),
      _RiderStatus.waiting => Text(
          'Waiting…',
          style: label?.copyWith(color: AppColors.textTertiary),
        ),
    };
  }
}
