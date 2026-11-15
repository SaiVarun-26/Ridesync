import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/pulse_indicator.dart';
import '../../../core/widgets/ride_loader.dart';
import '../../../core/widgets/section_label.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../room/domain/room.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../../room/presentation/room_flow.dart';
import '../../room/presentation/widgets/room_exit_scope.dart';
import '../domain/destination.dart';
import '../domain/guidance/route_guide.dart';
import '../domain/guidance/route_maneuvers.dart';
import '../domain/live/ride_format.dart';
import 'guidance/route_planner_controller.dart';
import 'planning/route_preview_map.dart';
import 'providers/guidance_providers.dart';
import 'widgets/slide_to_confirm.dart';

/// Guided-ride planning for room [roomCode].
///
/// The host searches for a destination (or long-presses the map), and the
/// road route from their position is computed and shared with the room at
/// once, so every rider watches the same route draw itself in. The host then
/// slides to start the ride; every screen follows the room into the live map.
/// Riders see the same overview and wait for the host.
class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  final TextEditingController _search = TextEditingController();

  String get _code => widget.roomCode;

  /// Room the panels take over the map, for framing the route between them.
  static const EdgeInsets _mapPadding = EdgeInsets.fromLTRB(0, 210, 0, 250);

  bool _listening = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The text last passed to the planner; the controller also notifies on
  /// cursor moves, which are not new searches.
  String _lastQuery = '';

  void _attachSearch(RoutePlannerController planner) {
    if (_listening) return;
    _listening = true;
    _search.addListener(() {
      final text = _search.text;
      if (text == _lastQuery) return;
      _lastQuery = text;
      planner.setQuery(text);
    });
  }

  void _choose(RoutePlannerController planner, PlaceSuggestion place) {
    FocusScope.of(context).unfocus();
    // Shows the chosen name without searching for it again.
    _lastQuery = place.primaryText;
    _search.text = place.primaryText;
    planner.choose(place);
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomStreamProvider(_code)).value;
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    ref.watch(roomPresenceProvider(_code));
    listenToRoomFlow(
      ref,
      context,
      code: _code,
      currentPath: AppRoutes.planningPath(_code),
    );
    final isHost = room != null && myUid != null && room.hostUid == myUid;
    final guideAsync = ref.watch(routeGuideProvider(_code));
    final guide = guideAsync.value;

    RoutePlannerState? plan;
    RoutePlannerController? planner;
    if (isHost) {
      plan = ref.watch(routePlannerControllerProvider(_code));
      final notifier = ref.read(routePlannerControllerProvider(_code).notifier);
      planner = notifier;
      _attachSearch(notifier);
      ref.listen<RoutePlannerState>(routePlannerControllerProvider(_code), (
        previous,
        next,
      ) {
        final notice = next.notice;
        if (notice != null && notice.id != previous?.notice?.id) {
          showAppSnackBar(context, notice.message);
        }
      });
    }

    final pending = plan != null && plan.isRouting
        ? plan.destination?.location
        : null;

    return RoomExitScope(
      roomCode: _code,
      builder: (context, _, _) => Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: RoutePreviewMap(
                guide: guide,
                origin: plan?.origin ?? ref.watch(currentPositionProvider).value,
                pendingDestination: pending,
                padding: _mapPadding,
                onLongPress: planner == null
                    ? null
                    : (point) {
                        FocusScope.of(context).unfocus();
                        planner!.pickOnMap(point);
                      },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      child: _TopPanel(
                        roomName: room?.name ?? '',
                        isHost: isHost,
                        search: _search,
                        plan: plan,
                        onChoose: planner == null
                            ? null
                            : (place) => _choose(planner!, place),
                      ),
                    ),
                    const Spacer(),
                    const _Credits(),
                    const SizedBox(height: AppSpacing.sm),
                    FadeSlideIn(
                      delay: AppMotion.stagger,
                      child: _RouteCard(
                        room: room,
                        isHost: isHost,
                        guide: guide,
                        isLoadingRoute: guideAsync.isLoading && guide == null,
                        plan: plan,
                        onStart: planner?.start,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPanel extends StatelessWidget {
  const _TopPanel({
    required this.roomName,
    required this.isHost,
    required this.search,
    required this.plan,
    required this.onChoose,
  });

  final String roomName;
  final bool isHost;
  final TextEditingController search;
  final RoutePlannerState? plan;
  final ValueChanged<PlaceSuggestion>? onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = this.plan;
    final suggestions = plan?.suggestions ?? const <PlaceSuggestion>[];
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionLabel(
            roomName.isEmpty ? 'GUIDED RIDE' : roomName.toUpperCase(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isHost ? 'Plan the route' : 'Guided Ride',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (isHost) ...[
            AppTextField(
              controller: search,
              hintText: 'Search a destination',
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
            ),
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              alignment: Alignment.topCenter,
              child: plan != null && (plan.isSearching || suggestions.isNotEmpty)
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: plan.isSearching && suggestions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(
                                child: RideLoader(size: RideLoader.inline),
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < suggestions.length; i++)
                                  FadeSlideIn(
                                    delay: AppMotion.stagger * i * 0.5,
                                    child: _SuggestionRow(
                                      place: suggestions[i],
                                      onTap: () => onChoose?.call(
                                        suggestions[i],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ] else
            const Row(
              children: [
                PulseIndicator(),
                SizedBox(width: AppSpacing.md),
                Expanded(child: Text('The host is planning the route.')),
              ],
            ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.place, required this.onTap});

  final PlaceSuggestion place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${place.primaryText}, ${place.secondaryText}',
      excludeSemantics: true,
      child: PressableScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: AppIconSize.medium,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.primaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (place.secondaryText.isNotEmpty)
                        Text(
                          place.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
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

/// The bottom card: the route summary, and for the host the slide that
/// starts the ride.
class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.room,
    required this.isHost,
    required this.guide,
    required this.isLoadingRoute,
    required this.plan,
    required this.onStart,
  });

  final Room? room;
  final bool isHost;
  final RouteGuide? guide;
  final bool isLoadingRoute;
  final RoutePlannerState? plan;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = this.plan;
    final guide = this.guide;
    final Widget body;
    if (plan != null && plan.isRouting) {
      body = Row(
        key: const ValueKey('routing'),
        children: [
          const RideLoader(size: RideLoader.inline),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Finding the best route to ${plan.destination?.name ?? 'there'}…',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      );
    } else if (guide == null) {
      body = Row(
        key: const ValueKey('empty'),
        children: [
          Icon(
            isHost ? Icons.touch_app_rounded : Icons.route_rounded,
            size: AppIconSize.large,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              isLoadingRoute
                  ? 'Loading the route…'
                  : isHost
                  ? (plan?.isLocating ?? false)
                        ? 'Finding your position… Then search above, or '
                              'long-press the map to drop a pin.'
                        : 'Search above, or long-press the map to drop a pin.'
                  : 'The route appears here as soon as the host picks it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    } else {
      body = _RouteSummary(
        key: ValueKey(guide.route.encodedPolyline.hashCode),
        guide: guide,
        room: room,
        isHost: isHost,
        isStarting: plan?.isStarting ?? false,
        onStart: onStart,
      );
    }
    return GlassPanel(
      child: AnimatedSize(
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: AppMotion.normal,
          switchInCurve: AppMotion.curve,
          switchOutCurve: AppMotion.exit,
          child: body,
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    super.key,
    required this.guide,
    required this.room,
    required this.isHost,
    required this.isStarting,
    required this.onStart,
  });

  final RouteGuide guide;
  final Room? room;
  final bool isHost;
  final bool isStarting;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = guide.route;
    final turns = guide.maneuvers
        .where((m) => m.kind != ManeuverKind.arrive)
        .length;
    final everyoneConnected = room?.everyoneConnected ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: Colors.white,
                size: AppIconSize.medium,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('DESTINATION'),
                  Text(
                    route.destinationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            _Figure(
              label: 'DISTANCE',
              value: RideFormat.distance(route.distanceMeters.toDouble()),
            ),
            _Figure(
              label: 'EST. TIME',
              value: RideFormat.eta(Duration(seconds: route.durationSeconds)),
            ),
            _Figure(label: 'TURNS', value: '$turns'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (isHost)
          // The slide only appears once every rider is connected, so it can
          // never be left locked after a refused start.
          AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.exit,
            child: everyoneConnected || isStarting
                ? SlideToConfirm(
                    key: const ValueKey('start'),
                    label: 'Slide to start the ride',
                    accent: AppColors.primary,
                    icon: Icons.play_arrow_rounded,
                    isBusy: isStarting,
                    onConfirmed: () => onStart?.call(),
                  )
                : const AppButton(
                    key: ValueKey('waiting'),
                    label: 'Waiting for every rider…',
                    onPressed: null,
                    variant: AppButtonVariant.secondary,
                    verticalPadding: 20,
                  ),
          )
        else
          Row(
            children: [
              const PulseIndicator(),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Waiting for the host to start…',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTypography.stat(fontSize: 22)),
          ),
          const SizedBox(height: AppSpacing.xs),
          SectionLabel(label),
        ],
      ),
    );
  }
}

/// Required credits for the open data and services used to plan.
class _Credits extends StatelessWidget {
  const _Credits();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        'Search: Photon · Routing: OSRM · © OpenStreetMap contributors',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
