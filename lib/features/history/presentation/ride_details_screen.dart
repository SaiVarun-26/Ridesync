import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/ride_loader.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/ride_details.dart';
import 'providers/ride_details_providers.dart';
import 'route/ride_route_map.dart';
import 'widgets/ride_details_sections.dart';

/// A finished ride in full: the route told on a map you can explore, and the
/// numbers in a sheet that slides over it. Laid out like an activity page in a
/// fitness app.
class RideDetailsScreen extends ConsumerWidget {
  const RideDetailsScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(rideDetailsProvider(roomCode));
    return Scaffold(
      body: details.when(
        loading: () => const _Frame(child: Center(child: _LoadingDot())),
        error: (error, _) => _Frame(
          child: _Failed(
            message: error is Failure
                ? error.message
                : 'Could not load this ride.',
            onRetry: () => ref.invalidate(rideDetailsProvider(roomCode)),
          ),
        ),
        data: (data) => _Content(details: data),
      ),
    );
  }
}

/// The screen's dark backdrop with its back button, used while loading and
/// when loading fails.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: _BackButton(),
          ),
        ),
      ],
    );
  }
}

class _LoadingDot extends StatelessWidget {
  const _LoadingDot();

  @override
  Widget build(BuildContext context) {
    return const RideLoader(size: RideLoader.hero);
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: AppIconButton(
        glass: true,
        icon: Icons.arrow_back_rounded,
        tooltip: 'Back',
        onPressed: () => context.pop(),
      ),
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({required this.details});

  final RideDetails details;

  @override
  ConsumerState<_Content> createState() => _ContentState();
}

class _ContentState extends ConsumerState<_Content>
    with SingleTickerProviderStateMixin {
  /// The rider whose route is highlighted, if any.
  String? _selectedUid;

  /// How much of the screen the sheet takes when it first appears.
  static const double _sheetStart = 0.46;
  static const double _sheetMin = 0.22;
  static const double _sheetMax = 0.94;

  // --- The opening sequence ------------------------------------------------
  //
  // One controller plays the whole story, each part running over its own span
  // of it: the map fades in, the camera settles on the ride, the route draws,
  // the speed colours arrive, the start and finish appear, then the arrows,
  // the numbers count up, and the rider lists fade in.

  static const int _introMs = 3300;
  static const Duration _mapWaitLimit = Duration(milliseconds: 1500);
  static const Duration _skipDuration = AppMotion.normal;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introMs),
  );
  final List<CurvedAnimation> _curved = [];

  Animation<double> _span(
    int fromMs,
    int toMs, [
    Curve curve = AppMotion.curve,
  ]) {
    final animation = CurvedAnimation(
      parent: _intro,
      curve: Interval(fromMs / _introMs, toMs / _introMs, curve: curve),
    );
    _curved.add(animation);
    return animation;
  }

  late final Animation<double> _mapCover = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(_span(0, 350));
  late final Animation<double> _statsReveal = _span(2400, 3000);
  late final Animation<double> _listsReveal = _span(2700, 3300);
  late final RouteReveal _reveal = RouteReveal(
    camera: _span(100, 1100, Curves.linear),
    draw: _span(700, 1500, AppMotion.move),
    heat: _span(1500, 1900),
    startMarker: _span(1800, 2100),
    finishMarker: _span(2000, 2350),
    arrows: _span(2250, 2650),
  );

  Animation<double>? _routeAnimation;
  Timer? _mapWait;
  bool _mapReady = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _mapWait = Timer(_mapWaitLimit, () {
      // The map should be ready long before this; if not, tell the story
      // anyway rather than leave the screen waiting.
      _mapReady = true;
      _maybeStart();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeAnimation == null) {
      _routeAnimation = ModalRoute.of(context)?.animation;
      _routeAnimation?.addStatusListener(_onRouteStatus);
    }
  }

  @override
  void dispose() {
    _mapWait?.cancel();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    for (final animation in _curved) {
      animation.dispose();
    }
    _intro.dispose();
    super.dispose();
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _maybeStart();
  }

  void _onMapReady() {
    _mapReady = true;
    // One frame so the map has painted before it is revealed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeStart();
    });
  }

  /// Starts the sequence once the map is ready and the page has finished
  /// opening, so the two never compete for frames.
  void _maybeStart() {
    if (_started || !_mapReady || !mounted) return;
    final route = _routeAnimation;
    if (route != null && route.status != AnimationStatus.completed) return;
    _started = true;
    _mapWait?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  /// The viewer touched the map: let the sequence finish at once.
  void _skipIntro() {
    if (_started && _intro.value >= 1) return;
    _started = true;
    _mapWait?.cancel();
    _intro.animateTo(1, duration: _skipDuration, curve: AppMotion.curve);
  }

  void _select(String? uid) {
    if (uid == _selectedUid) return;
    setState(() => _selectedUid = uid);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.details.summary;
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    final colors = {
      for (final rider in summary.riders) rider.uid: riderColorOf(rider),
    };
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top + 56;
    final selected = _selectedUid == null
        ? null
        : summary.riders.where((r) => r.uid == _selectedUid).firstOrNull;

    return Stack(
      children: [
        Positioned.fill(
          // Painted on its own layer, so the sheet sliding over it never
          // makes the map repaint.
          child: RepaintBoundary(
            child: RideRouteMap(
              details: widget.details,
              colors: colors,
              myUid: myUid,
              selectedUid: _selectedUid,
              onSelect: _select,
              topInset: topInset,
              bottomInset: size.height * _sheetStart,
              reveal: _reveal,
              onReady: _onMapReady,
              onInteract: _skipIntro,
            ),
          ),
        ),
        // Hides the map until it is ready and has painted, then fades away, so
        // it never visibly loads.
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _mapCover,
              child: const ColoredBox(color: AppColors.background),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BackButton(),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.normal,
                    switchInCurve: AppMotion.spring,
                    switchOutCurve: AppMotion.exit,
                    child: selected == null
                        ? const SizedBox(key: ValueKey('none'), height: 44)
                        : _SelectionChip(
                            key: ValueKey(selected.uid),
                            name: riderNameOf(selected),
                            color: riderColorOf(selected),
                            onClear: () => _select(null),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: _sheetStart,
          minChildSize: _sheetMin,
          maxChildSize: _sheetMax,
          snap: true,
          snapSizes: const [_sheetStart],
          builder: (context, controller) => _Sheet(
            controller: controller,
            details: widget.details,
            myUid: myUid,
            selectedUid: _selectedUid,
            onSelect: _select,
            statsReveal: _statsReveal,
            listsReveal: _listsReveal,
          ),
        ),
      ],
    );
  }
}

/// Names the highlighted rider on the map and clears the highlight.
class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    super.key,
    required this.name,
    required this.color,
    required this.onClear,
  });

  final String name;
  final Color color;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: onClear,
        child: GlassPanel(
          radius: 44,
          accent: color,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.close_rounded,
                size: AppIconSize.small,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.controller,
    required this.details,
    required this.myUid,
    required this.selectedUid,
    required this.onSelect,
    required this.statsReveal,
    required this.listsReveal,
  });

  final ScrollController controller;
  final RideDetails details;
  final String? myUid;
  final String? selectedUid;
  final ValueChanged<String?> onSelect;

  /// Counts the headline numbers up from zero.
  final Animation<double> statsReveal;

  /// Fades the rider lists in, one after another.
  final Animation<double> listsReveal;

  /// How much later each list starts than the one before, as a fraction of
  /// [listsReveal].
  static const double _listStep = 0.14;

  @override
  Widget build(BuildContext context) {
    final summary = details.summary;
    final theme = Theme.of(context);

    Widget section(int index, String title, Widget child, {String? hint}) {
      final timing = listsReveal.drive(
        CurveTween(
          curve: Interval(
            (index - 1) * _listStep,
            ((index - 1) * _listStep + 0.55).clamp(0.0, 1.0),
            curve: AppMotion.curve,
          ),
        ),
      );
      return FadeTransition(
        opacity: timing,
        child: SlideTransition(
          position: timing.drive(
            Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: DetailsSection(title: title, trailing: hint, child: child),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sheet,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (details.fromCache)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Offline. Showing the saved copy of this ride.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            RideTitleBlock(summary: summary),
            const SizedBox(height: AppSpacing.xl),
            RideHeroStats(group: summary.group, progress: statsReveal),
            section(
              1,
              'RIDERS',
              RiderListCard(
                riders: summary.riders,
                myUid: myUid,
                selectedUid: selectedUid,
                onSelect: onSelect,
              ),
              hint: 'Tap to highlight',
            ),
            section(
              2,
              'RANKINGS',
              RankingCard(riders: summary.riders, myUid: myUid),
            ),
            section(
              3,
              'FINISH ORDER',
              FinishOrderCard(riders: summary.riders, myUid: myUid),
            ),
            section(4, 'COMING SOON', const ComingSoonCard()),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.secondary,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
