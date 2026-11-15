import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/guidance/route_guide.dart';
import '../../domain/guidance/route_progress.dart';
import '../../domain/location_fix.dart';
import '../providers/guidance_providers.dart';
import '../providers/ride_map_providers.dart';

/// Everything the guided-ride UI shows about the route.
class GuidanceState {
  const GuidanceState({
    this.guide,
    this.snapshot,
    this.isLoading = false,
    this.offRouteDismissed = false,
    this.isReturning = false,
    this.arrivalAcknowledged = false,
  });

  /// The analysed route; `null` while loading or when there is none.
  final RouteGuide? guide;

  /// Where this rider stands on it; `null` until the first fix.
  final GuidanceSnapshot? snapshot;

  final bool isLoading;

  /// The rider chose to carry on off route: the warning shrinks to a chip.
  final bool offRouteDismissed;

  /// The rider asked for the way back: the return line shows.
  final bool isReturning;

  /// The rider closed the route-complete card.
  final bool arrivalAcknowledged;

  bool get hasRoute => guide != null;
  bool get isOffRoute => snapshot?.isOffRoute ?? false;
  bool get hasArrived => snapshot?.hasArrived ?? false;

  /// The full off-route warning (with its two choices) is up.
  bool get showsOffRouteWarning =>
      isOffRoute && !offRouteDismissed && !isReturning;

  /// Whether the camera may use the route's direction (on the line).
  bool get canUseRouteHeading =>
      snapshot != null && !isOffRoute && snapshot!.offsetMeters < 25;

  GuidanceState copyWith({
    GuidanceSnapshot? snapshot,
    bool? offRouteDismissed,
    bool? isReturning,
    bool? arrivalAcknowledged,
  }) => GuidanceState(
    guide: guide,
    snapshot: snapshot ?? this.snapshot,
    isLoading: isLoading,
    offRouteDismissed: offRouteDismissed ?? this.offRouteDismissed,
    isReturning: isReturning ?? this.isReturning,
    arrivalAcknowledged: arrivalAcknowledged ?? this.arrivalAcknowledged,
  );
}

/// Follows this rider along room [_code]'s planned route.
///
/// Feeds every GPS fix from the live map into a [RouteProgressTracker] and
/// publishes the result. Holds no widgets and no timers: it only reacts to
/// fixes (about one a second), so it adds nothing per frame.
class GuidanceController extends Notifier<GuidanceState> {
  GuidanceController(this._code);

  final String _code;
  RouteProgressTracker? _tracker;

  @override
  GuidanceState build() {
    final guideAsync = ref.watch(routeGuideProvider(_code));
    final guide = guideAsync.value;
    if (guide == null || !guide.isUsable) {
      _tracker = null;
      return GuidanceState(isLoading: guideAsync.isLoading);
    }
    final tracker = _tracker = RouteProgressTracker(guide);
    ref.listen<LocationFix?>(
      rideMapControllerProvider(_code).select((map) => map.myFix),
      (_, fix) {
        if (fix != null) _onFix(fix);
      },
    );
    final fix = ref.read(rideMapControllerProvider(_code)).myFix;
    return GuidanceState(
      guide: guide,
      snapshot: fix == null ? null : tracker.update(fix),
    );
  }

  void _onFix(LocationFix fix) {
    final tracker = _tracker;
    if (tracker == null) return;
    final average = ref
        .read(rideMapControllerProvider(_code))
        .myStats
        ?.averageSpeedMps;
    final snapshot = tracker.update(fix, averageSpeedMps: average);
    // Back on the line: the choices reset for next time.
    final back = !snapshot.isOffRoute;
    state = state.copyWith(
      snapshot: snapshot,
      offRouteDismissed: back ? false : null,
      isReturning: back ? false : null,
    );
  }

  /// Keep riding off route; the warning shrinks to a chip.
  void continueOffRoute() {
    if (!state.isOffRoute) return;
    state = state.copyWith(offRouteDismissed: true, isReturning: false);
  }

  /// Show the way back to the route.
  void returnToRoute() {
    if (!state.isOffRoute) return;
    state = state.copyWith(isReturning: true, offRouteDismissed: false);
  }

  /// Close the route-complete card.
  void acknowledgeArrival() {
    state = state.copyWith(arrivalAcknowledged: true);
  }
}
