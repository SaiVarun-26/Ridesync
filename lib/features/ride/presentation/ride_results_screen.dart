import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_text_button.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/section_label.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../history/domain/ride_details.dart';
import '../../history/presentation/providers/ride_details_providers.dart';
import '../../history/presentation/providers/ride_history_providers.dart';
import '../../history/presentation/providers/ride_transition_providers.dart';
import '../../history/presentation/widgets/ride_details_sections.dart';
import '../../history/presentation/widgets/speed_chart.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../../room/presentation/room_flow.dart';
import '../../room/presentation/widgets/room_exit_scope.dart';
import '../domain/live/ride_format.dart';
import '../domain/summary/ride_summary.dart';

/// Where every rider lands when the host ends the ride.
///
/// Makes finishing feel like something: a ring draws itself and checks off,
/// the headline numbers count up, a chart draws the rider's speed across the
/// ride, and bars show how the group compared. Reaching it also adds the ride
/// to the rider's history, and from here they can open the full ride or go
/// home.
class RideResultsScreen extends ConsumerStatefulWidget {
  const RideResultsScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<RideResultsScreen> createState() => _RideResultsScreenState();
}

class _RideResultsScreenState extends ConsumerState<RideResultsScreen> {
  bool _leaving = false;

  String get _code => widget.roomCode;

  /// Goes home. Waits for the ride to be saved to history first, because the
  /// rider has to still be in the room for that write to be allowed.
  Future<void> _done() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await ref.read(recordRideHistoryProvider(_code).future);
    } on Object {
      // History is best effort here; leaving must not be blocked by it.
    }
    final result = await ref
        .read(roomRepositoryProvider)
        .leaveRoom(code: _code);
    if (!mounted) return;
    switch (result) {
      case Success():
        context.go(AppRoutes.home);
      case Failed(:final failure):
        setState(() => _leaving = false);
        showAppSnackBar(context, failure.message);
    }
  }

  void _viewRide() {
    // No card to grow out of here, so the details simply fade in.
    ref.read(rideTransitionOriginProvider.notifier).set(null);
    context.push(AppRoutes.historyDetailsPath(_code));
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(roomPresenceProvider(_code))
      // Watched only to keep the history write alive while this is open.
      ..watch(recordRideHistoryProvider(_code));
    listenToRoomFlow(
      ref,
      context,
      code: _code,
      currentPath: AppRoutes.resultsPath(_code),
    );
    final details = ref.watch(rideDetailsProvider(_code));
    final myUid = ref.watch(authStateChangesProvider).value?.uid;

    return RoomExitScope(
      roomCode: _code,
      builder: (context, requestLeave, _) => Scaffold(
        body: AmbientBackground(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.slow,
                    switchInCurve: AppMotion.curve,
                    switchOutCurve: AppMotion.exit,
                    child: details.when(
                      loading: () => const _Title(
                        key: ValueKey('loading'),
                        name: null,
                        subtitle: 'Gathering your results…',
                      ),
                      error: (error, _) => _Failed(
                        key: const ValueKey('error'),
                        message: error is Failure
                            ? error.message
                            : 'Could not load your results.',
                        onRetry: () =>
                            ref.invalidate(rideDetailsProvider(_code)),
                      ),
                      data: (data) => _Results(
                        key: const ValueKey('results'),
                        details: data,
                        myUid: myUid,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppButton(
                        label: 'View ride',
                        icon: Icons.route_rounded,
                        onPressed: details.hasValue ? _viewRide : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Done',
                        variant: AppButtonVariant.secondary,
                        isLoading: _leaving,
                        onPressed: _done,
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

/// The ring that draws itself, with the headline beneath.
class _Title extends StatelessWidget {
  const _Title({super.key, required this.name, required this.subtitle});

  final String? name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CompleteBadge(),
          const SizedBox(height: AppSpacing.xl),
          Text('Ride Complete', style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name ?? subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CompleteBadge(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Ride Complete',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          AppTextButton(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}

/// The results themselves, revealed in order by one controller: the headline,
/// the counting numbers, the rider's standing, the speed chart, the group.
class _Results extends StatefulWidget {
  const _Results({super.key, required this.details, required this.myUid});

  final RideDetails details;
  final String? myUid;

  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results>
    with SingleTickerProviderStateMixin {
  static const int _totalMs = 2400;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  final List<CurvedAnimation> _curved = [];

  Animation<double> _span(
    int fromMs,
    int toMs, [
    Curve curve = AppMotion.curve,
  ]) {
    final a = CurvedAnimation(
      parent: _controller,
      curve: Interval(fromMs / _totalMs, toMs / _totalMs, curve: curve),
    );
    _curved.add(a);
    return a;
  }

  late final Animation<double> _numbers = _span(300, 1300);
  late final Animation<double> _standing = _span(900, 1500);
  // The chart line is drawn across, so it travels rather than arrives.
  late final Animation<double> _chart = _span(1100, 2000, AppMotion.move);
  late final Animation<double> _group = _span(1500, 2400);

  @override
  void initState() {
    super.initState();
    // Starts after the first frame, so the screen is on show before it moves.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    for (final a in _curved) {
      a.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  Widget _reveal(Animation<double> animation, Widget child) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: animation.drive(
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero),
      ),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final summary = widget.details.summary;
    final theme = Theme.of(context);
    final ranked = RideRankings.rank(summary.riders, RankMetric.distance);
    final myIndex = ranked.indexWhere((r) => r.uid == widget.myUid);
    final me = myIndex < 0 ? null : ranked[myIndex];
    final route = widget.details.routes[widget.myUid];
    final speeds = route != null && route.hasSpeeds
        ? route.smoothedSpeedsMps
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      children: [
        Column(
          children: [
            const _CompleteBadge(),
            const SizedBox(height: AppSpacing.xl),
            Text('Ride Complete', style: theme.textTheme.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              summary.roomName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        RideHeroStats(group: summary.group, progress: _numbers),
        if (me != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          _reveal(
            _standing,
            _Standing(rank: myIndex + 1, of: ranked.length, rider: me),
          ),
        ],
        if (speeds != null && speeds.length > 3) ...[
          const SizedBox(height: AppSpacing.xxl),
          _reveal(
            _standing,
            const Align(
              alignment: Alignment.centerLeft,
              child: SectionLabel('YOUR SPEED'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SpeedChart(speedsMps: speeds, progress: _chart),
        ],
        if (ranked.length > 1) ...[
          const SizedBox(height: AppSpacing.xxl),
          _reveal(
            _group,
            const Align(
              alignment: Alignment.centerLeft,
              child: SectionLabel('THE GROUP'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _GroupBars(riders: ranked, myUid: widget.myUid, progress: _group),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Where the rider placed, with their own three numbers.
class _Standing extends StatelessWidget {
  const _Standing({required this.rank, required this.of, required this.rider});

  final int rank;
  final int of;
  final RiderRideSummary rider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      accent: AppColors.primary,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: Text(
              '#$rank',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  of == 1 ? 'You rode solo' : 'You placed $rank of $of',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${RideFormat.distance(rider.distanceMeters)}  ·  '
                  'avg ${RideFormat.speed(rider.averageSpeedMps)}  ·  '
                  'top ${RideFormat.speed(rider.maxSpeedMps)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A bar for each rider, as long as their share of the furthest distance,
/// growing as the section reveals.
class _GroupBars extends StatelessWidget {
  const _GroupBars({
    required this.riders,
    required this.myUid,
    required this.progress,
  });

  final List<RiderRideSummary> riders;
  final String? myUid;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final furthest = riders.first.distanceMeters <= 0
        ? 1.0
        : riders.first.distanceMeters;
    return AppCard(
      child: Column(
        children: [
          for (final rider in riders.indexed) ...[
            if (rider.$1 > 0) const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    riderNameOf(rider.$2) +
                        (rider.$2.uid == myUid ? ' (you)' : ''),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  RideFormat.distance(rider.$2.distanceMeters),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _Bar(
              fraction: rider.$2.distanceMeters / furthest,
              color: riderColorOf(rider.$2),
              progress: progress,
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.progress,
  });

  final double fraction;
  final Color color;
  final Animation<double> progress;

  static const double _height = 8;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_height),
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AppColors.surfaceRaised),
            ),
            AnimatedBuilder(
              animation: progress,
              builder: (context, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (fraction * progress.value).clamp(0.0, 1.0),
                child: DecoratedBox(decoration: BoxDecoration(color: color)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A ring that draws itself, then its check mark springs in.
class _CompleteBadge extends StatelessWidget {
  const _CompleteBadge();

  static const double _size = 76;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      // The ring closes, then the check springs in: two brand entrances back
      // to back, so it reads as one finished moment.
      duration: AppMotion.entrance + AppMotion.slow,
      curve: AppMotion.curve,
      builder: (context, t, _) {
        final check = AppMotion.spring.transform(
          ((t - 0.4) / 0.6).clamp(0.0, 1.0),
        );
        return SizedBox.square(
          dimension: _size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: _size,
                child: CustomPaint(painter: _RingPainter(t)),
              ),
              Transform.scale(
                scale: check,
                child: Opacity(
                  opacity: check.clamp(0.0, 1.0),
                  child: const Icon(
                    Icons.check_rounded,
                    size: AppIconSize.hero,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A ring that draws itself clockwise from the top, as far as [progress].
class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  static const double _stroke = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    canvas
      ..drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..color = AppColors.border,
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
