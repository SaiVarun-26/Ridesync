import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../ride/domain/live/ride_format.dart';
import '../../domain/ride_history_entry.dart';
import '../ride_mode_label.dart';
import 'route_thumbnail.dart';

/// One finished ride in a list: a miniature of its route beside its name,
/// date, mode and numbers.
///
/// Pressing it lifts it: it scales in a touch while its shadow deepens and
/// spreads. [onTap] is given the card's place on screen, which the details
/// screen grows out of.
class RideHistoryCard extends StatefulWidget {
  const RideHistoryCard({super.key, required this.entry, required this.onTap});

  final RideHistoryEntry entry;
  final ValueChanged<Rect> onTap;

  @override
  State<RideHistoryCard> createState() => _RideHistoryCardState();
}

class _RideHistoryCardState extends State<RideHistoryCard> {
  bool _lifted = false;

  void _open(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    widget.onTap(box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.card + 4);
    return PressableScale(
      onPressedChanged: (down) => setState(() => _lifted = down),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: _lifted
                ? AppColors.neonGreen.withValues(alpha: 0.35)
                : AppColors.divider,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _lifted ? 0.6 : 0.4),
              blurRadius: _lifted ? 30 : 18,
              offset: Offset(0, _lifted ? 14 : 8),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Row(
                children: [
                  RouteThumbnail(points: entry.routePreview),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.roomName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${RideFormat.date(entry.endedAt)}  ·  '
                          '${entry.mode.label}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            _Figure(
                              value: RideFormat.distance(entry.distanceMeters),
                              label: 'DIST',
                            ),
                            _Figure(
                              value: RideFormat.duration(entry.duration),
                              label: 'TIME',
                            ),
                            _Figure(
                              value: '${entry.riderCount}',
                              label: entry.riderCount == 1 ? 'RIDER' : 'RIDERS',
                            ),
                          ],
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
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  static const double _valueSize = 15;
  static const double _labelSpacing = 1.1;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTypography.stat(fontSize: _valueSize)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: _labelSpacing,
            ),
          ),
        ],
      ),
    );
  }
}
