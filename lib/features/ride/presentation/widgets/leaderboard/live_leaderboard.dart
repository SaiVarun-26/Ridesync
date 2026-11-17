import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/feedback/app_haptics.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/rider_palette.dart';
import '../../../../../core/widgets/app_icon.dart';
import '../../../../../core/widgets/glass_panel.dart';
import '../../../../../core/widgets/pressable_scale.dart';
import '../../../domain/leaderboard/leaderboard.dart';
import '../../leaderboard/leaderboard_controller.dart';
import '../../providers/ride_map_providers.dart';
import '../../ride_map_controller.dart';

/// "+34 m", "−28 m", "Nearby": a gap along the shared path as a rider reads
/// it at a glance.
String leaderboardGap(double meters) {
  final a = meters.abs();
  if (a < nearbyMeters) return 'Nearby';
  final sign = meters > 0 ? '+' : '\u2212';
  if (a < 1000) return '$sign${(a / 5).round() * 5} m';
  final km = a / 1000;
  return '$sign${km >= 10 ? km.round() : km.toStringAsFixed(1)} km';
}

/// Riders closer than this along the path are side by side.
const double nearbyMeters = 15;

/// The floating live leaderboard of room [roomCode]: every online rider in
/// order of how far along they are, with their colour, name, live speed and
/// how far ahead or behind this rider they are.
///
/// It lives in the free space between the cards at the top of the map and
/// the controls at the bottom, on the left, no wider than [maxWidth]; the
/// screen chooses [maxWidth] so it stays clear of this rider's marker in the
/// middle. When the rows do not fit, they scroll. The header shows how many
/// riders are online and where this rider stands, and folds the list away.
///
/// Fades in once a second rider is on the map. Rows glide to their new place
/// when someone overtakes; speeds cross-fade.
class LiveLeaderboard extends ConsumerStatefulWidget {
  const LiveLeaderboard({
    super.key,
    required this.roomCode,
    required this.maxWidth,
  });

  final String roomCode;
  final double maxWidth;

  @override
  ConsumerState<LiveLeaderboard> createState() => _LiveLeaderboardState();
}

class _LiveLeaderboardState extends ConsumerState<LiveLeaderboard> {
  bool _collapsed = false;

  static const double rowHeight = 44;
  static const double _headerHeight = 30;
  static const double _padding = AppSpacing.sm;

  void _toggle() {
    AppHaptics.selection();
    setState(() => _collapsed = !_collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(leaderboardControllerProvider(widget.roomCode));
    final riders = ref.watch(
      rideMapControllerProvider(widget.roomCode).select((m) => m.riders),
    );
    final entries = board.entries;
    final show = entries.length >= 2;
    return AnimatedSwitcher(
      duration: AppMotion.slow,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      child: !show
          ? const SizedBox.shrink(key: ValueKey('none'))
          : LayoutBuilder(
              key: const ValueKey('board'),
              builder: (context, constraints) => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: _board(board, riders, constraints.maxHeight),
              ),
            ),
    );
  }

  Widget _board(
    LeaderboardState board,
    Map<String, LiveRider> riders,
    double maxHeight,
  ) {
    final entries = board.entries;
    final me = entries.where((e) => e.isMe).firstOrNull;
    final listHeight = entries.length * rowHeight;
    final room = maxHeight.isFinite
        ? math.max(0.0, maxHeight - _headerHeight - _padding * 3)
        : listHeight;
    // Too short to show even two rows: just the header.
    final collapsed = _collapsed || room < rowHeight * 2;
    return GlassPanel(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(_padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            online: entries.length,
            members: math.max(board.memberCount, entries.length),
            myRank: me?.rank,
            collapsed: collapsed,
            onTap: room < rowHeight * 2 ? null : _toggle,
          ),
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.curve,
            alignment: Alignment.topCenter,
            child: collapsed
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: _padding),
                    child: SizedBox(
                      height: math.min(listHeight, room),
                      child: SingleChildScrollView(
                        physics: listHeight > room
                            ? const BouncingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        child: AnimatedContainer(
                          duration: AppMotion.normal,
                          curve: AppMotion.curve,
                          height: listHeight,
                          child: Stack(
                            children: [
                              for (final entry in entries)
                                AnimatedPositioned(
                                  // Keyed by rider, so an overtake glides
                                  // both rows to their new places.
                                  key: ValueKey(entry.uid),
                                  duration: AppMotion.slow,
                                  curve: AppMotion.move,
                                  left: 0,
                                  right: 0,
                                  top: (entry.rank - 1) * rowHeight,
                                  height: rowHeight,
                                  child: _Row(
                                    entry: entry,
                                    rider: riders[entry.uid],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The board's header: how many riders are online (the ride's rider count
/// lives here, so it can never sit on top of the board or the navigation
/// card), where this rider stands, and the fold control.
class _Header extends StatelessWidget {
  const _Header({
    required this.online,
    required this.members,
    required this.myRank,
    required this.collapsed,
    required this.onTap,
  });

  final int online;
  final int members;
  final int? myRank;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = online == members ? '$online' : '$online/$members';
    final header = SizedBox(
      height: _LiveLeaderboardState._headerHeight,
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.groups_rounded,
            size: AppIconSize.small,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            count,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          if (myRank != null)
            Flexible(
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Text(
                  'You #$myRank',
                  key: ValueKey(myRank),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (onTap != null)
            AnimatedRotation(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              turns: collapsed ? 0 : 0.5,
              child: const Icon(
                Icons.expand_more_rounded,
                size: AppIconSize.medium,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
    final label = [
      '$online of $members riders online',
      if (myRank != null) 'you are number $myRank',
    ].join(', ');
    if (onTap == null) {
      return Semantics(label: label, excludeSemantics: true, child: header);
    }
    return Semantics(
      button: true,
      label: '$label. ${collapsed ? 'Show' : 'Fold'} the leaderboard.',
      excludeSemantics: true,
      child: PressableScale(
        haptic: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: header,
        ),
      ),
    );
  }
}

/// One rider: a badge in their colour holding their place, their name, and
/// beneath it their live speed and how far ahead or behind they are. Two
/// lines, so the name gets the full width of even a narrow board.
class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.rider});

  final LeaderboardEntry entry;
  final LiveRider? rider;

  static const double _badge = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = entry.isMe;
    final color =
        RiderPalette.colorById(rider?.colorId)?.color ?? AppColors.textPrimary;
    final name = me ? 'You' : leaderboardNameOf(rider);
    final kmh = (entry.speedMps * 3.6).round();
    final gap = entry.gapMeters;
    final (String? note, Color noteColor) = entry.isOffPath
        ? ('Off route', AppColors.error)
        : gap == null
        ? (null, AppColors.textTertiary)
        : (
            leaderboardGap(gap),
            gap.abs() < nearbyMeters || gap < 0
                ? AppColors.textSecondary
                : AppColors.textPrimary,
          );
    final semantics = [
      'Position ${entry.rank}',
      name,
      '$kmh kilometres per hour',
      if (entry.isOffPath) 'off route',
      if (!entry.isOffPath && gap != null)
        gap.abs() < nearbyMeters
            ? 'nearby'
            : '${gap.abs().round()} metres ${gap > 0 ? 'ahead' : 'behind'}',
    ].join(', ');
    const tight = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    );

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        // A rider joining the board fades in where they belong.
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: AnimatedContainer(
            duration: AppMotion.normal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: me
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: me
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: _badge,
                  height: _badge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                  child: Text(
                    '${entry.rank}',
                    textHeightBehavior: tight,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.background,
                      fontWeight: FontWeight.w800,
                      fontSize: entry.rank >= 10 ? 9 : 11,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textHeightBehavior: tight,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: me ? FontWeight.w700 : FontWeight.w500,
                          fontSize: me ? 14 : 13,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          // Speed changes cross-fade instead of flicking.
                          // On a very narrow board the figure shrinks a
                          // touch rather than overflow.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  AnimatedSwitcher(
                                    duration: AppMotion.fast,
                                    switchInCurve: AppMotion.curve,
                                    switchOutCurve: AppMotion.exit,
                                    layoutBuilder: (current, previous) => Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [...previous, ?current],
                                    ),
                                    child: Text(
                                      '$kmh',
                                      key: ValueKey(kmh),
                                      textHeightBehavior: tight,
                                      style: AppTypography.stat(
                                        fontSize: me ? 13 : 12,
                                      ).copyWith(height: 1.1),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'km/h',
                                    textHeightBehavior: tight,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.textTertiary,
                                      fontSize: 9,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (note != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: AppMotion.fast,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.centerRight,
                                  children: [...previous, ?current],
                                ),
                                child: Text(
                                  note,
                                  key: ValueKey(note),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                  textAlign: TextAlign.right,
                                  textHeightBehavior: tight,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: noteColor,
                                    fontSize: 10,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
