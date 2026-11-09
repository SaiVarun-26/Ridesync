import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/glow_button.dart';
import '../../../core/widgets/section_label.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../room/domain/room.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../../room/presentation/room_flow.dart';
import '../../room/presentation/widgets/room_exit_scope.dart';
import '../../room/presentation/widgets/room_state_views.dart';
import '../domain/route_model.dart';
import 'providers/route_providers.dart';
import 'widgets/destination_card.dart';
import 'widgets/destination_search_sheet.dart';
import 'widgets/ride_start_transition.dart';

/// Guided-ride planning for room [roomCode], shown to the whole group after
/// initialization.
///
/// The host searches for a destination; the server generates the route and
/// shares it, so every rider's card updates live. When the host starts the
/// ride, every device plays the three-second start sequence and then moves to
/// the ride together.
class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  /// The running start sequence, shared by repeated room updates so it plays
  /// exactly once.
  Completer<void>? _startTransition;

  /// Destination shown in the start sequence.
  String? _startingDestination;

  /// Example destinations for a quick search. Not persisted yet.
  static const List<String> _recentDestinations = [
    'Mahabalipuram',
    'Marina Beach',
    'ECR Ride',
    'Yelagiri',
  ];

  String get _code => widget.roomCode;

  Future<void> _playStartTransition(Room room) {
    final running = _startTransition;
    if (running != null) return running.future;
    final transition = Completer<void>();
    _startTransition = transition;
    setState(() {
      _startingDestination =
          ref.read(plannedRouteProvider(_code)).value?.destinationName ?? '';
    });
    return transition.future;
  }

  void _onTransitionFinished() {
    final transition = _startTransition;
    if (transition != null && !transition.isCompleted) transition.complete();
  }

  Future<void> _openSearch({String initialQuery = ''}) async {
    final controller =
        ref.read(guidedPlanningControllerProvider(_code).notifier);
    final near = await controller.searchBias();
    if (!mounted) return;
    final choice = await showDestinationSearchSheet(
      context: context,
      initialQuery: initialQuery,
      near: near,
    );
    if (choice != null) await controller.chooseDestination(choice);
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(_code));
    final route = ref.watch(plannedRouteProvider(_code)).value;
    final planning = ref.watch(guidedPlanningControllerProvider(_code));
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    ref.watch(roomPresenceProvider(_code));
    listenToRoomFlow(
      ref,
      context,
      code: _code,
      currentPath: AppRoutes.planningPath(_code),
      beforeLeaving: _playStartTransition,
    );
    ref.listen(
      guidedPlanningControllerProvider(_code).select((s) => s.errorId),
      (_, _) {
        final error = ref.read(guidedPlanningControllerProvider(_code)).error;
        if (error == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      },
    );

    final starting = _startingDestination;
    return RoomExitScope(
      roomCode: _code,
      builder: (context, _, _) => Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: roomAsync.when(
                loading: () => const RoomLoadingView(),
                error: (_, _) =>
                    const RoomMessageView(message: RoomMessageView.loadError),
                data: (room) {
                  if (room == null) {
                    return const RoomMessageView(
                      message: RoomMessageView.unavailable,
                    );
                  }
                  return _PlanningContent(
                    room: room,
                    route: route,
                    planning: planning,
                    isHost: room.hostUid == myUid,
                    recentDestinations: _recentDestinations,
                    onSearch: _openSearch,
                    onStart: ref
                        .read(guidedPlanningControllerProvider(_code).notifier)
                        .startRide,
                  );
                },
              ),
            ),
            if (starting != null)
              Positioned.fill(
                child: RideStartTransition(
                  destinationName: starting,
                  onFinished: _onTransitionFinished,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanningContent extends StatelessWidget {
  const _PlanningContent({
    required this.room,
    required this.route,
    required this.planning,
    required this.isHost,
    required this.recentDestinations,
    required this.onSearch,
    required this.onStart,
  });

  final Room room;
  final PlannedRoute? route;
  final PlanningState planning;
  final bool isHost;
  final List<String> recentDestinations;
  final Future<void> Function({String initialQuery}) onSearch;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit = isHost && !planning.isGenerating && !planning.isStarting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              SectionLabel(room.name.toUpperCase()),
              const SizedBox(height: AppSpacing.sm),
              Text('Guided Ride', style: theme.textTheme.displaySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose where the group is heading.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeSlideIn(
                child: _SearchCard(
                  enabled: canEdit,
                  hint: isHost
                      ? 'Search destination'
                      : 'The host is choosing the destination',
                  onTap: () => onSearch(),
                ),
              ),
              if (isHost) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('RECENT DESTINATIONS'),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final name in recentDestinations)
                      ActionChip(
                        label: Text(name),
                        onPressed: canEdit
                            ? () => onSearch(initialQuery: name)
                            : null,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              FadeSlideIn(
                delay: const Duration(milliseconds: 90),
                child: DestinationCard(
                  route: route,
                  pendingDestination: planning.pendingDestination,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: isHost
              ? _HostAction(
                  room: room,
                  route: route,
                  planning: planning,
                  onStart: onStart,
                )
              : const GlowButton(label: 'Waiting for Host...', onPressed: null),
        ),
      ],
    );
  }
}

class _HostAction extends StatelessWidget {
  const _HostAction({
    required this.room,
    required this.route,
    required this.planning,
    required this.onStart,
  });

  final Room room;
  final PlannedRoute? route;
  final PlanningState planning;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final String? hint;
    if (route == null) {
      hint = 'Choose a destination to start.';
    } else if (!room.everyoneConnected) {
      final offline = room.members.where((m) => !m.online).length;
      hint = offline == 1
          ? 'Waiting for 1 rider to reconnect.'
          : 'Waiting for $offline riders to reconnect.';
    } else {
      hint = null;
    }
    final canStart = hint == null && !planning.isGenerating;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.normal,
          child: hint == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey<String>(hint),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
        ),
        GlowButton(
          label: 'START RIDE',
          isLoading: planning.isStarting,
          onPressed: canStart ? onStart : null,
        ),
      ],
    );
  }
}

/// The large frosted search field. Opens the search sheet for the host and
/// stays disabled for riders.
class _SearchCard extends StatefulWidget {
  const _SearchCard({
    required this.enabled,
    required this.hint,
    required this.onTap,
  });

  final bool enabled;
  final String hint;
  final VoidCallback onTap;

  @override
  State<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<_SearchCard> {
  bool _pressed = false;

  static const double _blurSigma = 18;
  static const double _fillAlpha = 0.04;
  static const double _borderAlpha = 0.10;
  static const double _glowAlpha = 0.18;
  static const double _glowBlur = 28;
  static const double _glowSpread = -8;
  static const double _pressedScale = 1.02;
  static const double _disabledOpacity = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.lg);
    return AnimatedOpacity(
      duration: AppMotion.normal,
      opacity: widget.enabled ? 1 : _disabledOpacity,
      child: AnimatedScale(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        scale: _pressed ? _pressedScale : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: AppColors.route.withValues(alpha: _glowAlpha),
                      blurRadius: _glowBlur,
                      spreadRadius: _glowSpread,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
              child: Material(
                color: AppColors.textPrimary.withValues(alpha: _fillAlpha),
                shape: RoundedRectangleBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color:
                        AppColors.textPrimary.withValues(alpha: _borderAlpha),
                  ),
                ),
                child: InkWell(
                  borderRadius: radius,
                  splashColor: Colors.transparent,
                  onTap: widget.enabled ? widget.onTap : null,
                  onHighlightChanged: (pressed) =>
                      setState(() => _pressed = pressed),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xl,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.route),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Text(
                            widget.hint,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
