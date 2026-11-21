import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../history/data/pending_ride_uploads.dart';
import '../../../history/presentation/providers/ride_history_providers.dart';
import '../../../room/presentation/providers/room_providers.dart';
import 'ride_completion_providers.dart';

/// The on-device queue of finished rides still to be uploaded.
final pendingRideUploadsStoreProvider = Provider<PendingRideUploads>((ref) {
  return PendingRideUploads(ref.watch(rideCacheProvider));
});

/// The signed-in rider's finished rides that have not reached the cloud yet,
/// and the worker that uploads them.
///
/// Offline flow: the ride ends, its record is saved on the device (the
/// Realtime Database keeps unsent writes on disk), the ride is queued here,
/// and the moment the connection returns, on this run of the app or a later
/// one, it is published to the rider's history. Kept alive by the app root.
final pendingRideUploadsProvider =
    NotifierProvider<PendingRideUploadsController, List<PendingRideUpload>>(
      PendingRideUploadsController.new,
    );

class PendingRideUploadsController extends Notifier<List<PendingRideUpload>> {
  String? _uid;

  /// Rides an open ride screen is saving itself right now; the worker leaves
  /// those alone so the same ride is not published twice at once.
  final Set<String> _active = {};

  bool _connected = false;
  bool _draining = false;
  Timer? _retry;

  /// Serialises queue file updates.
  Future<void> _queue = Future<void>.value();

  static const Duration _retryDelay = Duration(seconds: 30);

  /// Rides that still cannot be published after this long are dropped.
  static const Duration _maxAge = Duration(days: 30);

  @override
  List<PendingRideUpload> build() {
    _uid = ref.watch(authStateChangesProvider.select((a) => a.value?.uid));
    _connected = false;
    _draining = false;
    _retry?.cancel();
    if (_uid == null) return const [];

    final connection = ref
        .read(roomRepositoryProvider)
        .watchConnection()
        .listen((connected) {
          _connected = connected;
          if (connected) unawaited(drain());
        }, onError: (Object _) {});
    ref.onDispose(() {
      connection.cancel();
      _retry?.cancel();
    });
    unawaited(_load());
    return const [];
  }

  PendingRideUploads get _store => ref.read(pendingRideUploadsStoreProvider);

  Future<void> _load() async {
    final items = await _store.all();
    if (!ref.mounted) return;
    state = _mine(items);
    if (_connected) unawaited(drain());
  }

  List<PendingRideUpload> _mine(List<PendingRideUpload> items) => [
    for (final item in items)
      if (item.uid == _uid) item,
  ];

  Future<void> _update(
    Future<List<PendingRideUpload>> Function() change,
  ) async {
    final done = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        final items = await change();
        if (ref.mounted) state = _mine(items);
      } catch (e) {
        debugPrint('[uploads] Updating the queue failed: $e');
      } finally {
        done.complete();
      }
    });
    return done.future;
  }

  /// Queues ride [code] (for [uid], saved as [name]) and marks it as being
  /// saved by the ride screen. Call [release] when that screen stops.
  Future<void> enqueue({
    required String uid,
    required String code,
    required String name,
  }) {
    _active.add(code);
    return _update(
      () => _store.add(
        PendingRideUpload(
          uid: uid,
          code: code,
          name: name,
          queuedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  /// Ride [code] is uploaded: off the queue.
  Future<void> complete({required String uid, required String code}) {
    _active.remove(code);
    return _update(() => _store.remove(uid: uid, code: code));
  }

  /// The ride screen saving [code] has gone; the worker takes over.
  void release(String code) {
    if (!_active.remove(code)) return;
    if (_connected) unawaited(drain());
  }

  /// Uploads every queued ride not being saved by a ride screen. Runs when
  /// the connection returns and every [_retryDelay] while anything is left.
  Future<void> drain() async {
    final uid = _uid;
    if (uid == null || _draining || !ref.mounted) return;
    _draining = true;
    _retry?.cancel();
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final item in List<PendingRideUpload>.of(state)) {
        if (!ref.mounted || !_connected) return;
        if (_active.contains(item.code)) continue;
        if (now - item.queuedAtMs > _maxAge.inMilliseconds) {
          debugPrint('[uploads] Dropping ${item.code}: too old to publish.');
          await complete(uid: uid, code: item.code);
          continue;
        }
        final result = await ref
            .read(rideCompletionServiceProvider)
            .publishMyFinish(code: item.code, uid: uid, name: item.name);
        if (!ref.mounted) return;
        if (result is Success) {
          debugPrint('[uploads] Uploaded ${item.code}.');
          await complete(uid: uid, code: item.code);
          if (ref.mounted) {
            unawaited(ref.read(rideHistoryProvider.notifier).refresh());
          }
        } else {
          debugPrint('[uploads] ${item.code} not uploaded yet: $result');
        }
      }
    } finally {
      _draining = false;
      if (ref.mounted &&
          state.any((i) => !_active.contains(i.code)) &&
          _connected) {
        _retry = Timer(_retryDelay, () => unawaited(drain()));
      }
    }
  }
}
