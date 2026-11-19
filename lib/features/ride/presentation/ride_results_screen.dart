import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_text_button.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_icon.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../history/presentation/providers/ride_details_providers.dart';
import '../../history/presentation/providers/ride_history_providers.dart';
import '../../history/presentation/story/ride_story_view.dart';
import '../../naming/presentation/naming_providers.dart';
import '../../naming/presentation/ride_name_dialog.dart';
import '../../insights/presentation/providers/insights_providers.dart';
import '../../insights/presentation/share/ride_share_sheet.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../../room/presentation/room_flow.dart';
import '../../room/presentation/widgets/room_exit_scope.dart';

/// Where every rider lands when the host ends the ride.
///
/// The ride is told as a story of cards (see [RideStoryView]): the solo
/// journey, or the group's ride with its replay, standings and moments.
/// Reaching it also adds the ride to the rider's history (with its recap
/// highlights). The story ends with the share card; Done goes home.
class RideResultsScreen extends ConsumerStatefulWidget {
  const RideResultsScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<RideResultsScreen> createState() => _RideResultsScreenState();
}

class _RideResultsScreenState extends ConsumerState<RideResultsScreen> {
  bool _leaving = false;

  String get _code => widget.roomCode;

  /// Whether this rider is the host of a ride nobody has named yet. Their
  /// copy is saved to history only once it is named.
  bool get _hostNeedsToName {
    final summary = ref.read(rideDetailsProvider(_code)).value?.summary;
    final uid = ref.read(authStateChangesProvider).value?.uid;
    return summary != null && !summary.named && summary.hostUid == uid;
  }

  /// Asks the host for the ride's name and, once it is saved, saves the ride
  /// to their history.
  Future<void> _nameRide() async {
    final details = ref.read(rideDetailsProvider(_code)).value;
    final uid = ref.read(authStateChangesProvider).value?.uid;
    if (details == null) return;
    final points = details.routes[uid]?.points;
    final service = ref.read(rideNamingServiceProvider);
    final saved = await showRideNameDialog(
      context,
      title: 'Name your ride',
      confirmLabel: 'Save Ride',
      message: 'Everyone will see it in their history.',
      suggestion: service.suggest(
        start: points == null || points.isEmpty ? null : points.first,
        end: points == null || points.isEmpty ? null : points.last,
      ),
      onSave: (name) async {
        final result = await service.nameRide(code: _code, name: name);
        return switch (result) {
          Success() => null,
          Failed(:final failure) => failure.message,
        };
      },
    );
    if (!saved || !mounted) return;
    // The ride is named now: show it, and save it to history.
    ref
      ..invalidate(rideDetailsProvider(_code))
      ..invalidate(rideRecapProvider(_code))
      ..invalidate(recordRideHistoryProvider(_code));
  }

  /// Goes home. Waits for the ride to be saved to history first, because the
  /// rider has to still be in the room for that write to be allowed.
  Future<void> _done() async {
    if (_leaving) return;
    if (_hostNeedsToName) {
      // Leaving now would leave the ride out of the host's history.
      final leave = await showAppDialog<bool>(
        context: context,
        builder: (_) => const AppDialog(
          title: 'Leave without saving?',
          message:
              'This ride has no name yet, so it is not in your history. '
              'Name it to keep it.',
          cancelLabel: 'Name ride',
          confirmLabel: 'Leave',
          destructive: true,
        ),
      );
      if (!mounted) return;
      if (leave != true) {
        await _nameRide();
        return;
      }
    }
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
    final recap = ref.watch(rideRecapProvider(_code));
    // Saves this ride's highlights to its history entry once it is recorded.
    ref
      ..watch(recapHighlightsSyncProvider)
      // Picks up the host's name as soon as it is given.
      ..watch(pendingNameSyncProvider);
    // The room's name updates live, so riders see the host's name arrive.
    final room = ref.watch(roomStreamProvider(_code)).value;
    final liveName = room == null || room.namePending ? null : room.name;
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
                      data: (data) => RideStoryView(
                        key: const ValueKey('results'),
                        details: data,
                        myUid: myUid,
                        // Arrives a moment after the results, from the
                        // background; its cards join as it does.
                        recap: recap.value,
                        completed: true,
                        title:
                            liveName ??
                            (data.summary.named
                                ? null
                                : 'Waiting for the host to name this ride'),
                        onShare: () => showRideShareSheet(context, code: _code),
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
                      if (details.value case final loaded?)
                        if (!loaded.summary.named &&
                            loaded.summary.hostUid == myUid) ...[
                          AppButton(
                            label: 'Name & save ride',
                            icon: Icons.edit_rounded,
                            onPressed: _nameRide,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
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
