import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../../history/domain/ride_history_entry.dart';
import '../../history/presentation/providers/ride_history_providers.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../data/nominatim_reverse_geocoder.dart';
import '../data/rtdb_ride_name_store.dart';
import '../domain/ride_name_store.dart';
import '../domain/ride_naming_service.dart';
import '../domain/reverse_geocoder.dart';

/// Finds the area a position is in, from OpenStreetMap.
final reverseGeocoderProvider = Provider<ReverseGeocoder>((ref) {
  return NominatimReverseGeocoder();
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
