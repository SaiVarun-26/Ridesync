import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../history/domain/ride_history_entry.dart';
import '../../../history/presentation/providers/ride_history_providers.dart';
import '../../../ride/presentation/providers/pending_upload_providers.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../domain/rider_stats.dart';

/// The rider's statistics across their whole history.
///
/// Read from the cloud (every ride, not only the loaded page); offline, from
/// the rides on this device.
final riderStatsProvider = FutureProvider.autoDispose<RiderStats>((ref) async {
  final uid = ref.watch(authStateChangesProvider.select((a) => a.value?.uid));
  if (uid == null) return RiderStats.empty;
  final repository = ref.read(rideHistoryRepositoryProvider);
  final all = await repository.allEntries(uid);
  switch (all) {
    case Success(:final value):
      return RiderStats.from(value);
    case Failed():
      final shown = ref.read(rideHistoryProvider).entries;
      final cached = shown.isNotEmpty ? shown : await repository.cached(uid);
      return RiderStats.from(_unique(cached));
  }
});

Iterable<RideHistoryEntry> _unique(List<RideHistoryEntry> entries) => {
  for (final e in entries) e.code: e,
}.values;

/// Whether the phone is connected to the cloud right now.
final cloudConnectionProvider = StreamProvider.autoDispose<bool>((ref) {
  return ref.watch(roomRepositoryProvider).watchConnection();
});

/// What the profile's cloud sync pill shows.
enum CloudSyncStatus { synced, syncing, offline }

/// Whether a Sync Now is running.
final syncNowProvider = NotifierProvider.autoDispose<SyncNowController, bool>(
  SyncNowController.new,
);

class SyncNowController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Fetches the profile, the history and the statistics from the cloud
  /// again, and uploads any ride still waiting. Returns whether the profile
  /// could be reached.
  Future<bool> run() async {
    if (state) return true;
    state = true;
    try {
      unawaited(ref.read(pendingRideUploadsProvider.notifier).drain());
      final results = await Future.wait<Object?>([
        ref.read(authRepositoryProvider).refreshProfile(),
        ref.read(rideHistoryProvider.notifier).refresh(),
      ]);
      if (!ref.mounted) return false;
      ref.invalidate(riderStatsProvider);
      return results.first is Success;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

/// The cloud sync status: offline when there is no connection; syncing while
/// Sync Now runs, a profile change is still on its way up, or a finished
/// ride is waiting to upload; synced otherwise.
final cloudSyncStatusProvider = Provider.autoDispose<CloudSyncStatus>((ref) {
  final connected = ref.watch(cloudConnectionProvider).value ?? true;
  if (!connected) return CloudSyncStatus.offline;
  final syncing = ref.watch(syncNowProvider);
  final pendingProfile = ref.watch(
    userProfileProvider.select((p) => p.value?.hasPendingWrites ?? false),
  );
  final pendingRides = ref.watch(
    pendingRideUploadsProvider.select((items) => items.isNotEmpty),
  );
  return syncing || pendingProfile || pendingRides
      ? CloudSyncStatus.syncing
      : CloudSyncStatus.synced;
});
