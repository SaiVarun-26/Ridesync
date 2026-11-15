import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../domain/destination.dart';
import '../../domain/geo_point.dart';
import '../../domain/route_model.dart';
import '../providers/guidance_providers.dart';
import '../providers/ride_init_providers.dart';

/// A one-off message for the planning screen to show.
class PlannerNotice {
  const PlannerNotice(this.message, this.id);

  final String message;

  /// Distinguishes two notices with the same text.
  final int id;
}

/// The host's planning session.
class RoutePlannerState {
  const RoutePlannerState({
    this.origin,
    this.isLocating = true,
    this.query = '',
    this.suggestions = const [],
    this.isSearching = false,
    this.destination,
    this.isRouting = false,
    this.isStarting = false,
    this.notice,
  });

  /// Where the route starts: the host's position.
  final GeoPoint? origin;
  final bool isLocating;

  final String query;
  final List<PlaceSuggestion> suggestions;
  final bool isSearching;

  /// The place being routed to (before and after the route is shared).
  final Destination? destination;

  /// A route is being computed and shared.
  final bool isRouting;

  /// The ride is being started.
  final bool isStarting;

  final PlannerNotice? notice;

  RoutePlannerState copyWith({
    GeoPoint? origin,
    bool? isLocating,
    String? query,
    List<PlaceSuggestion>? suggestions,
    bool? isSearching,
    Destination? destination,
    bool? isRouting,
    bool? isStarting,
    PlannerNotice? notice,
  }) => RoutePlannerState(
    origin: origin ?? this.origin,
    isLocating: isLocating ?? this.isLocating,
    query: query ?? this.query,
    suggestions: suggestions ?? this.suggestions,
    isSearching: isSearching ?? this.isSearching,
    destination: destination ?? this.destination,
    isRouting: isRouting ?? this.isRouting,
    isStarting: isStarting ?? this.isStarting,
    notice: notice ?? this.notice,
  );
}

/// Runs the host's side of planning a guided ride for room [_code]: find a
/// destination (search or a pin on the map), compute the road route from the
/// host's position, share it with the room, and start the ride.
///
/// The route on screen is always the one stored in the room, so the host and
/// every rider see exactly the same preview.
class RoutePlannerController extends Notifier<RoutePlannerState> {
  RoutePlannerController(this._code);

  final String _code;
  Timer? _debounce;
  int _searchGeneration = 0;
  int _routeGeneration = 0;
  int _noticeId = 0;

  static const Duration _debounceDelay = Duration(milliseconds: 350);
  static const Duration _locateTimeout = Duration(seconds: 10);
  static const int _minQueryLength = 2;

  @override
  RoutePlannerState build() {
    ref.onDispose(() => _debounce?.cancel());
    unawaited(_locate());
    return const RoutePlannerState();
  }

  Future<GeoPoint?> _locate() async {
    final point = await ref
        .read(locationRepositoryProvider)
        .currentPosition(timeout: _locateTimeout);
    if (!ref.mounted) return null;
    state = point == null
        ? state.copyWith(isLocating: false)
        : state.copyWith(origin: point, isLocating: false);
    return point;
  }

  /// The search text changed; results follow after a short pause in typing.
  void setQuery(String query) {
    _debounce?.cancel();
    final text = query.trim();
    if (text.length < _minQueryLength) {
      _searchGeneration++;
      state = state.copyWith(query: text, suggestions: const [], isSearching: false);
      return;
    }
    state = state.copyWith(query: text, isSearching: true);
    _debounce = Timer(_debounceDelay, () => unawaited(_search(text)));
  }

  Future<void> _search(String text) async {
    final generation = ++_searchGeneration;
    final result = await ref
        .read(routeRepositoryProvider)
        .searchDestinations(text, near: state.origin);
    // A newer search (or a cleared field) wins.
    if (!ref.mounted || generation != _searchGeneration) return;
    switch (result) {
      case Success(:final value):
        state = state.copyWith(suggestions: value, isSearching: false);
      case Failed(:final failure):
        state = state.copyWith(
          isSearching: false,
          notice: _notice(failure.message),
        );
    }
  }

  /// Clears the search results (the field was emptied or closed).
  void clearSuggestions() {
    _debounce?.cancel();
    _searchGeneration++;
    state = state.copyWith(suggestions: const [], isSearching: false);
  }

  /// Routes to a search result.
  Future<void> choose(PlaceSuggestion suggestion) async {
    clearSuggestions();
    final result = await ref
        .read(routeRepositoryProvider)
        .resolveDestination(suggestion.placeId);
    if (!ref.mounted) return;
    switch (result) {
      case Success(:final value):
        await _routeTo(value);
      case Failed(:final failure):
        state = state.copyWith(notice: _notice(failure.message));
    }
  }

  /// Routes to a point picked on the map.
  Future<void> pickOnMap(GeoPoint point) async {
    clearSuggestions();
    final generation = ++_routeGeneration;
    state = state.copyWith(
      isRouting: true,
      destination: Destination(name: 'Pinned location', location: point),
    );
    final named = await ref.read(routeRepositoryProvider).describeLocation(point);
    if (!ref.mounted || generation != _routeGeneration) return;
    await _routeTo(
      named.valueOrNull ?? Destination(name: 'Pinned location', location: point),
      generation: generation,
    );
  }

  Future<void> _routeTo(Destination destination, {int? generation}) async {
    final run = generation ?? ++_routeGeneration;
    state = state.copyWith(destination: destination, isRouting: true);
    final origin = state.origin ?? await _locate();
    if (!ref.mounted || run != _routeGeneration) return;
    if (origin == null) {
      state = state.copyWith(
        isRouting: false,
        notice: _notice('Waiting for your location. Try again in a moment.'),
      );
      return;
    }
    final estimate = await ref
        .read(routeRepositoryProvider)
        .computeRoute(origin: origin, destination: destination.location);
    if (!ref.mounted || run != _routeGeneration) return;
    if (estimate case Failed(:final failure)) {
      state = state.copyWith(
        isRouting: false,
        notice: _notice(failure.message),
      );
      return;
    }
    final route = (estimate as Success<RouteEstimate>).value;
    final saved = await ref
        .read(sharedRouteRepositoryProvider)
        .save(
          code: _code,
          route: PlannedRoute(
            destinationName: destination.name,
            destination: destination.location,
            encodedPolyline: route.encodedPolyline,
            distanceMeters: route.distanceMeters,
            durationSeconds: route.durationSeconds,
          ),
        );
    if (!ref.mounted || run != _routeGeneration) return;
    state = state.copyWith(
      isRouting: false,
      notice: switch (saved) {
        Failed(:final failure) => _notice(failure.message),
        Success() => null,
      },
    );
  }

  /// Starts the guided ride for everyone. On success the room moves to
  /// riding and every rider's screen follows it.
  Future<void> start() async {
    if (state.isStarting) return;
    state = state.copyWith(isStarting: true);
    final result = await ref
        .read(roomRepositoryProvider)
        .startGuidedRide(code: _code);
    if (!ref.mounted) return;
    if (result case Failed(:final failure)) {
      state = state.copyWith(isStarting: false, notice: _notice(failure.message));
    }
  }

  PlannerNotice _notice(String message) => PlannerNotice(message, ++_noticeId);
}
