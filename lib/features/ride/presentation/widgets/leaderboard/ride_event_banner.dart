import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/feedback/app_haptics.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/rider_palette.dart';
import '../../../../../core/widgets/app_icon.dart';
import '../../../../../core/widgets/glass_panel.dart';
import '../../../domain/leaderboard/leaderboard.dart';
import '../../leaderboard/leaderboard_controller.dart';
import '../../live/rider_state_notices.dart';
import '../../providers/ride_map_providers.dart';

/// A small banner that slides down from the top when another rider leaves
/// the group's path (or the planned route) or rejoins it, and slides away
/// again after a few seconds. Events that arrive together wait their turn;
/// a tap dismisses one early.
class RideEventBanner extends ConsumerStatefulWidget {
  const RideEventBanner({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<RideEventBanner> createState() => _RideEventBannerState();
}

/// One banner to show: a path event, or a rider's pause, resume or finish.
class _Notice {
  const _Notice({
    required this.key,
    required this.uid,
    required this.message,
    required this.icon,
    required this.accent,
  });

  factory _Notice.path(AnnouncedEvent e) {
    final left = e.event.kind == RidePathEventKind.left;
    return _Notice(
      key: 'path-${e.id}',
      uid: e.event.uid,
      message: e.message,
      icon: left ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
      accent: left ? AppColors.error : AppColors.primary,
    );
  }

  factory _Notice.rider(RiderStateNotice n) => _Notice(
    key: 'rider-${n.id}',
    uid: n.uid,
    message: n.message,
    icon: switch (n.change) {
      RiderStateChange.paused => Icons.pause_circle_rounded,
      RiderStateChange.resumed => Icons.play_circle_rounded,
      RiderStateChange.completed => Icons.flag_rounded,
    },
    accent: AppColors.primary,
  );

  final String key;
  final String uid;
  final String message;
  final IconData icon;
  final Color accent;
}

class _RideEventBannerState extends ConsumerState<RideEventBanner> {
  final Queue<_Notice> _queue = Queue();
  _Notice? _showing;
  Timer? _timer;

  static const Duration _showFor = Duration(milliseconds: 3800);

  /// Most events waiting; older ones are dropped rather than replayed late.
  static const int _maxQueued = 3;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _enqueue(_Notice event) {
    _queue.add(event);
    while (_queue.length > _maxQueued) {
      _queue.removeFirst();
    }
    if (_showing == null) _next();
  }

  void _next() {
    _timer?.cancel();
    if (!mounted) return;
    if (_queue.isEmpty) {
      setState(() => _showing = null);
      return;
    }
    final event = _queue.removeFirst();
    setState(() => _showing = event);
    AppHaptics.light();
    _timer = Timer(_showFor, _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _showing = null);
    // Let the banner slide away before the next one comes in.
    _timer = Timer(AppMotion.slow, _next);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AnnouncedEvent?>(
      leaderboardControllerProvider(widget.roomCode).select((s) => s.latest),
      (previous, next) {
        if (next != null && next.id != previous?.id) {
          _enqueue(_Notice.path(next));
        }
      },
    );
    ref.listen<RiderStateNotice?>(riderStateNoticeProvider(widget.roomCode), (
      previous,
      next,
    ) {
      if (next != null && next.id != previous?.id) {
        _enqueue(_Notice.rider(next));
      }
    });
    final showing = _showing;
    return AnimatedSwitcher(
      duration: AppMotion.slow,
      switchInCurve: AppMotion.spring,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.4),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: showing == null
          ? const SizedBox(key: ValueKey('none'), width: double.infinity)
          : _Banner(
              key: ValueKey(showing.key),
              event: showing,
              roomCode: widget.roomCode,
              onTap: _dismiss,
            ),
    );
  }
}

class _Banner extends ConsumerWidget {
  const _Banner({
    super.key,
    required this.event,
    required this.roomCode,
    required this.onTap,
  });

  final _Notice event;
  final String roomCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorId = ref.watch(
      rideMapControllerProvider(roomCode).select((m) => m.colorIds[event.uid]),
    );
    final riderColor =
        RiderPalette.colorById(colorId)?.color ?? AppColors.textPrimary;
    final accent = event.accent;
    return Semantics(
      liveRegion: true,
      button: true,
      label: '${event.message}. Tap to dismiss.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          accent: accent,
          radius: AppRadius.pill,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(event.icon, size: AppIconSize.medium, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: riderColor,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  event.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
