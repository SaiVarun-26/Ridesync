import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../data/rtdb_ride_signal_repository.dart';
import '../../domain/safety/ride_signal.dart';
import '../../domain/safety/ride_signal_repository.dart';
import '../providers/ride_map_providers.dart';

/// The group's safety signals.
final rideSignalRepositoryProvider = Provider<RideSignalRepository>((ref) {
  return RtdbRideSignalRepository(
    database: ref.watch(firebaseDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
  );
});

/// Safety signals for this rider in room [code].
final safetyControllerProvider = NotifierProvider.autoDispose
    .family<SafetyController, SafetyState, String>(SafetyController.new);

/// What the safety UI shows.
class SafetyState {
  const SafetyState({
    this.mine,
    this.alerts = const [],
    this.sending,
    this.lastResult,
  });

  /// This rider's own latest signal.
  final RideSignal? mine;

  /// Other riders' signals worth showing now: attention calls first (they
  /// stay until cleared), then recent signals, newest first.
  final List<RideSignal> alerts;

  /// The kind being sent right now, if any.
  final RideSignalKind? sending;

  /// The outcome of the last send, for a confirmation or an error.
  final SafetyResult? lastResult;

  /// Whether this rider has an attention call up.
  bool get needsAttention => mine?.kind == RideSignalKind.attention;
}

/// The outcome of one send.
class SafetyResult {
  const SafetyResult({required this.kind, required this.id, this.error});

  final RideSignalKind? kind;
  final int id;
  final String? error;
}

/// Sends this rider's safety signals and decides which of everyone else's to
/// show.
///
/// An attention call stays up until its rider clears it. Other signals show
/// for [_transientFor] after they arrive. Signals already present when the
/// ride screen opens are old news and are not replayed, except attention
/// calls, which always show.
class SafetyController extends Notifier<SafetyState> {
  SafetyController(this._code);

  final String _code;
  Map<String, RideSignal> _signals = const {};
  final Map<String, int> _receivedAt = {};
  bool _first = true;
  Timer? _expiry;
  int _resultId = 0;

  static const Duration _transientFor = Duration(seconds: 12);

  String? get _myUid => ref.read(authStateChangesProvider).value?.uid;

  @override
  SafetyState build() {
    final sub = ref
        .read(rideSignalRepositoryProvider)
        .watch(code: _code)
        .listen(_onSignals, onError: (Object _) {});
    ref.onDispose(() {
      _expiry?.cancel();
      unawaited(sub.cancel());
    });
    return const SafetyState();
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  void _onSignals(Map<String, RideSignal> next) {
    final now = _now;
    for (final entry in next.entries) {
      final previous = _signals[entry.key];
      if (previous == entry.value) continue;
      // Already there when the screen opened: mark as long gone, unless it
      // is an attention call.
      _receivedAt[entry.key] = _first && !entry.value.kind.isPersistent
          ? now - _transientFor.inMilliseconds - 1
          : now;
    }
    _receivedAt.removeWhere((uid, _) => !next.containsKey(uid));
    _signals = next;
    _first = false;
    _publish();
  }

  void _publish() {
    if (!ref.mounted) return;
    final now = _now;
    final me = _myUid;
    final alerts = <RideSignal>[];
    int? nextExpiry;
    for (final signal in _signals.values) {
      if (signal.uid == me) continue;
      if (signal.kind.isPersistent) {
        alerts.add(signal);
        continue;
      }
      final received = _receivedAt[signal.uid] ?? 0;
      final expires = received + _transientFor.inMilliseconds;
      if (expires > now) {
        alerts.add(signal);
        if (nextExpiry == null || expires < nextExpiry) nextExpiry = expires;
      }
    }
    alerts.sort((a, b) {
      final rank = (b.kind.isPersistent ? 1 : 0) - (a.kind.isPersistent ? 1 : 0);
      if (rank != 0) return rank;
      return (_receivedAt[b.uid] ?? 0) - (_receivedAt[a.uid] ?? 0);
    });
    _expiry?.cancel();
    if (nextExpiry != null) {
      _expiry = Timer(
        Duration(milliseconds: nextExpiry - now + 50),
        _publish,
      );
    }
    state = SafetyState(
      mine: me == null ? null : _signals[me],
      alerts: alerts,
      sending: state.sending,
      lastResult: state.lastResult,
    );
  }

  /// Sends [kind] to the group, with this rider's position.
  Future<void> send(RideSignalKind kind) async {
    if (state.sending != null) return;
    _setSending(kind);
    final at = ref.read(rideMapControllerProvider(_code)).myFix?.point;
    final result = await ref
        .read(rideSignalRepositoryProvider)
        .send(code: _code, kind: kind, at: at);
    if (!ref.mounted) return;
    _finish(kind, result);
  }

  /// Takes this rider's signal down (clearing an attention call says "OK").
  Future<void> clearAttention() => send(RideSignalKind.ok);

  void _setSending(RideSignalKind? kind) {
    state = SafetyState(
      mine: state.mine,
      alerts: state.alerts,
      sending: kind,
      lastResult: state.lastResult,
    );
  }

  void _finish(RideSignalKind kind, Result<void> result) {
    state = SafetyState(
      mine: state.mine,
      alerts: state.alerts,
      lastResult: SafetyResult(
        kind: kind,
        id: ++_resultId,
        error: switch (result) {
          Failed(:final failure) => failure.message,
          Success() => null,
        },
      ),
    );
  }
}
