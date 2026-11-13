import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/json_cache.dart';
import '../../data/rtdb_ride_history_repository.dart';
import '../../domain/ride_history_entry.dart';
import '../../domain/ride_history_repository.dart';
import '../thumbnail/route_thumbnail_layout.dart';

/// Where ride history and ride details are kept on the device.
final rideCacheProvider = Provider<JsonCache>((ref) {
  return FileJsonCache(() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}ride_cache');
  });
});

/// Reads and records the signed-in rider's finished rides.
final rideHistoryRepositoryProvider = Provider<RideHistoryRepository>((ref) {
  return RtdbRideHistoryRepository(
    database: ref.watch(firebaseDatabaseProvider),
    cache: ref.watch(rideCacheProvider),
  );
});

/// What the history screens show.
class RideHistoryState {
  const RideHistoryState({
    this.entries = const [],
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.fromCache = false,
    this.error,
  });

  /// Rides, newest first.
  final List<RideHistoryEntry> entries;

  /// Whether older rides can still be loaded.
  final bool hasMore;

  /// Whether the first page is still loading.
  final bool isLoading;
  final bool isLoadingMore;

  /// Whether [entries] come from the device because the network was
  /// unavailable.
  final bool fromCache;

  /// Why the latest load failed, if it did.
  final String? error;

  RideHistoryState copyWith({
    List<RideHistoryEntry>? entries,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    bool? fromCache,
    String? error,
    bool clearError = false,
  }) {
    return RideHistoryState(
      entries: entries ?? this.entries,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      fromCache: fromCache ?? this.fromCache,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The rider's ride history, loaded once and extended a page at a time.
///
/// Nothing is streamed: the first page loads when the history is first shown
/// (the device's copy appears immediately while the network answers), and
/// later pages load only when the rider scrolls to them.
final rideHistoryProvider =
    NotifierProvider<RideHistoryController, RideHistoryState>(
      RideHistoryController.new,
    );

class RideHistoryController extends Notifier<RideHistoryState> {
  String? _uid;
  bool _busy = false;
  bool _refreshAgain = false;

  @override
  RideHistoryState build() {
    // Only the uid matters: a different rider means a different history.
    _uid = ref.watch(authStateChangesProvider.select((a) => a.value?.uid));
    _busy = false;
    if (_uid == null) return const RideHistoryState(isLoading: false);
    Future<void>.microtask(refresh);
    return const RideHistoryState();
  }

  RideHistoryRepository get _repository =>
      ref.read(rideHistoryRepositoryProvider);

  /// Loads the newest rides again, keeping what is shown until they arrive.
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    if (_busy) {
      // A load is already running; run once more when it finishes so the
      // newest ride is not missed.
      _refreshAgain = true;
      return;
    }
    _busy = true;
    try {
      if (state.entries.isEmpty) {
        final cached = await _repository.cached(uid);
        if (!ref.mounted) return;
        if (cached.isNotEmpty) {
          _warm(cached);
          state = state.copyWith(entries: cached, fromCache: true);
        }
      }
      state = state.copyWith(
        isLoading: state.entries.isEmpty,
        clearError: true,
      );

      final result = await _repository.loadPage(uid: uid);
      if (!ref.mounted) return;
      switch (result) {
        case Success(:final value):
          _warm(value.entries);
          state = RideHistoryState(
            entries: value.entries,
            hasMore: value.hasMore,
            isLoading: false,
          );
          unawaited(_fillMissingPreviews());
        case Failed(:final failure):
          state = state.copyWith(
            isLoading: false,
            error: failure.message,
            fromCache: state.entries.isNotEmpty,
          );
      }
    } finally {
      _busy = false;
      if (_refreshAgain && ref.mounted) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    }
  }

  /// Rides whose preview has been tried, so one without a recorded route is
  /// not fetched again and again.
  final Set<String> _previewTried = {};

  /// Gives every ride that has no route preview its own, built from its
  /// recorded GPS route, one ride at a time so the first page stays quick.
  Future<void> _fillMissingPreviews() async {
    final uid = _uid;
    if (uid == null) return;
    for (final entry in List<RideHistoryEntry>.of(state.entries)) {
      if (entry.routePreview.isNotEmpty || !_previewTried.add(entry.code)) {
        continue;
      }
      final filled = await _repository.generatePreview(uid: uid, entry: entry);
      if (!ref.mounted) return;
      if (filled == null) continue;
      _warm([filled]);
      state = state.copyWith(
        entries: [
          for (final e in state.entries) e.code == filled.code ? filled : e,
        ],
      );
    }
  }

  /// Lays out each ride's route miniature ahead of time, so the cards draw
  /// instantly when they scroll into view instead of working it out then.
  void _warm(Iterable<RideHistoryEntry> entries) {
    for (final entry in entries) {
      RouteThumbnailLayout.of(entry.routePreview, entry.previewSpeedsMps);
    }
  }

  /// Loads the next older page. Does nothing while another load is running or
  /// when there are no older rides.
  Future<void> loadMore() async {
    final uid = _uid;
    if (uid == null || _busy || !state.hasMore || state.entries.isEmpty) return;
    _busy = true;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final result = await _repository.loadPage(
        uid: uid,
        after: state.entries.last,
      );
      if (!ref.mounted) return;
      switch (result) {
        case Success(:final value):
          _warm(value.entries);
          state = state.copyWith(
            entries: [...state.entries, ...value.entries],
            hasMore: value.hasMore,
            isLoadingMore: false,
          );
          unawaited(_fillMissingPreviews());
        case Failed(:final failure):
          state = state.copyWith(isLoadingMore: false, error: failure.message);
      }
    } finally {
      _busy = false;
    }
  }
}

/// Adds the finished ride [code] to the rider's history, then refreshes the
/// list. Watched by the results screen.
final recordRideHistoryProvider = FutureProvider.autoDispose
    .family<void, String>((ref, code) async {
      final uid = ref.read(authStateChangesProvider).value?.uid;
      if (uid == null) return;
      final result = await ref
          .read(rideHistoryRepositoryProvider)
          .record(uid: uid, code: code);
      if (result.isSuccess && ref.mounted) {
        unawaited(ref.read(rideHistoryProvider.notifier).refresh());
      }
    });
