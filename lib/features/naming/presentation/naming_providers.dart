import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../history/domain/ride_history_entry.dart';
import '../../history/presentation/providers/ride_details_providers.dart';
import '../../history/presentation/providers/ride_history_providers.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../data/nominatim_reverse_geocoder.dart';
import '../data/rtdb_ride_name_store.dart';
import '../domain/ride_name_store.dart';
import '../domain/ride_naming_service.dart';
import '../domain/ride_title_generator.dart';
import '../domain/reverse_geocoder.dart';

/// Finds the area a position is in, from OpenStreetMap.
final reverseGeocoderProvider = Provider<ReverseGeocoder>((ref) {
  return NominatimReverseGeocoder();
});

/// The name suggested for this rider's ride [code], from where their own
/// ride ended ("Ride to Marina Beach"). Never fails: when the place cannot
/// be found, or takes too long, it is [RideNames.fallback]. The same for
/// every ride type, however the ride ended.
final rideNameSuggestionProvider = FutureProvider.autoDispose
    .family<String, String>((ref, code) async {
      final uid = ref.read(authStateChangesProvider).value?.uid;
      // Already saved (when the ride ended): that name, as it is.
      if (uid != null) {
        final saved = await ref
            .read(rideHistoryRepositoryProvider)
            .entry(uid: uid, code: code);
        if (saved case Success(:final value?)) return value.roomName;
      }
      final details = await ref.watch(rideDetailsProvider(code).future);
      final points = details.routes[uid]?.points ?? const [];
      final service = ref.read(rideNamingServiceProvider);
      return service
          .suggest(
            start: points.isEmpty ? null : points.first,
            end: points.isEmpty ? null : points.last,
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => RideNames.fallback,
          );
    });

/// Saves ride names.
final rideNameStoreProvider = Provider<RideNameStore>((ref) {
  return RtdbRideNameStore(
    database: ref.watch(firebaseDatabaseProvider),
    cache: ref.watch(rideCacheProvider),
  );
});

/// The one service every ride uses to suggest, check, save and sync names.
final rideNamingServiceProvider = Provider<RideNamingService>((ref) {
  return RideNamingService(
    geocoder: ref.watch(reverseGeocoderProvider),
    store: ref.watch(rideNameStoreProvider),
  );
});

/// Brings rides saved before their host named them up to date: once the host
/// has named a ride, the name is copied onto this rider's history entry.
///
/// Watched by the screens that show history. While no ride is waiting it does
/// nothing. A ride the host has not named yet is looked at again every little
/// while for a few minutes, so a rider sitting on the home screen sees the
/// name arrive.
final pendingNameSyncProvider = Provider.autoDispose<void>((ref) {
  final sync = _NameSync(ref);
  ref
    ..listen<RideHistoryState>(
      rideHistoryProvider,
      (_, next) => unawaited(sync.check(next.entries)),
      fireImmediately: true,
    )
    ..onDispose(sync.stop);
});

class _NameSync {
  _NameSync(this._ref);

  final Ref _ref;
  bool _running = false;
  bool _again = false;
  bool _stopped = false;
  Timer? _retry;

  /// How often a ride still waiting is looked at again, and how many times.
  static const Duration _retryEvery = Duration(seconds: 20);
  static const int _maxAttempts = 9;
  static final Map<String, int> _attempts = {};

  void stop() {
    _stopped = true;
    _retry?.cancel();
  }

  Future<void> check(List<RideHistoryEntry> entries) async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    var stillWaiting = false;
    try {
      final uid = _ref.read(authStateChangesProvider).value?.uid;
      if (uid == null) return;
      final service = _ref.read(rideNamingServiceProvider);
      for (final entry in List<RideHistoryEntry>.of(entries)) {
        if (_stopped) return;
        if (!entry.namePending) continue;
        final attempts = _attempts[entry.code] ?? 0;
        if (attempts >= _maxAttempts) continue;
        _attempts[entry.code] = attempts + 1;
        final name = await service.syncSharedName(uid: uid, code: entry.code);
        if (_stopped) return;
        if (name == null) {
          stillWaiting = true;
          continue;
        }
        _ref.read(rideHistoryProvider.notifier).applyName(entry.code, name);
      }
    } finally {
      _running = false;
      if (_again && !_stopped) {
        _again = false;
        unawaited(check(_ref.read(rideHistoryProvider).entries));
      } else if (stillWaiting && !_stopped) {
        _retry?.cancel();
        _retry = Timer(
          _retryEvery,
          () => unawaited(check(_ref.read(rideHistoryProvider).entries)),
        );
      }
    }
  }
}
