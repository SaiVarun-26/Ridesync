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
import '../../../core/widgets/app_icon.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../history/presentation/providers/ride_details_providers.dart';
import '../../history/presentation/providers/ride_history_providers.dart';
import '../../history/presentation/story/ride_story_view.dart';
import '../../naming/presentation/naming_providers.dart';
import '../../naming/presentation/rename_ride_flow.dart';
import '../../insights/presentation/providers/insights_providers.dart';
import '../../insights/presentation/share/ride_share_sheet.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../../room/presentation/room_flow.dart';
import '../../room/presentation/widgets/room_exit_scope.dart';

/// Where each rider lands when their own ride ends, however it ended.
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

  /// The name this rider gave the ride here; `null` while it is still the
  /// suggested one.
  String? _chosenName;

  /// Lets the rider keep, edit or replace their ride's name. The ride is in
  /// their history already (under the suggested name); the new name replaces
  /// it there and everywhere the ride is shown.
  Future<void> _rename(String current) async {
    try {
      await ref.read(recordRideHistoryProvider(_code).future);
    } on Object {
      // Renaming below reports its own failure.
    }
    if (!mounted) return;
    final renamed = await renameRideFlow(
      context,
      ref,
      code: _code,
      currentName: current,
    );
    if (renamed != null && mounted) setState(() => _chosenName = renamed);
  }

  /// Goes home. Waits for the ride to be saved to history first, because the
  /// rider has to still be in the room for that write to be allowed.
  Future<void> _done() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await ref.read(recordRideHistoryProvider(_code).future);
    } on Object {
      // Checked just below.
    }
    // Leaving gives up the right to save the ride, so the rider only leaves
    // once it is in their history: a finished ride is never dropped.
    final uid = ref.read(authStateChangesProvider).value?.uid;
    final saved = uid == null
        ? null
        : await ref
              .read(rideHistoryRepositoryProvider)
              .entry(uid: uid, code: _code);
    if (!mounted) return;
    final inHistory = switch (saved) {
      Success(:final value) => value != null,
      _ => false,
    };
    if (!inHistory) {
      setState(() => _leaving = false);
      ref.invalidate(recordRideHistoryProvider(_code));
      showAppSnackBar(
        context,
        'Your ride is still being saved. Try again in a moment.',
      );
      return;
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
      // Brings older rides, saved before they were named, up to date.
      ..watch(pendingNameSyncProvider);
    // Named from where this rider's ride ended, and always editable.
    final suggested = ref.watch(rideNameSuggestionProvider(_code)).value;
    final name = _chosenName ?? suggested;
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
                        title: name ?? 'Naming your ride…',
                        onRename: name == null ? null : () => _rename(name),
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
