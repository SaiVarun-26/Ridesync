import 'dart:async';
import 'dart:developer' as developer;

import 'init_task.dart';

/// The rider-visible state of one initialization step.
class InitStepState {
  const InitStepState({
    required this.id,
    required this.label,
    this.phase = InitStepPhase.pending,
    this.message,
    this.blocker,
  });

  final String id;
  final String label;
  final InitStepPhase phase;

  /// Status text while waiting.
  final String? message;

  /// The required rider action while blocked.
  final InitBlocker? blocker;

  bool get isDone => phase == InitStepPhase.done;

  InitStepState _apply(InitTaskUpdate update) => InitStepState(
        id: id,
        label: label,
        phase: update.phase,
        message: update.message,
        blocker: update.blocker,
      );
}

/// Runs a ride's initialization plan, one task after another, and reports
/// every step's state.
///
/// Pure Dart (no Flutter, no Firebase), so the sequencing rules are testable:
/// - A step shows done only when its task reports done; nothing is simulated.
/// - A blocked step pauses the plan until [retry] is called.
/// - A failing task is retried automatically after [retryDelay].
class RideInitializer {
  RideInitializer(
    List<InitTask> tasks, {
    this.retryDelay = const Duration(seconds: 2),
  })  : _tasks = List<InitTask>.unmodifiable(tasks),
        _steps = [
          for (final task in tasks)
            InitStepState(id: task.id, label: task.label),
        ];

  /// Pause before re-running a task that failed.
  final Duration retryDelay;

  final List<InitTask> _tasks;
  final List<InitStepState> _steps;
  final StreamController<List<InitStepState>> _progress =
      StreamController<List<InitStepState>>.broadcast();

  bool _started = false;
  bool _disposed = false;
  StreamSubscription<InitTaskUpdate>? _active;
  Completer<_Outcome>? _attempt;
  Completer<void>? _retrySignal;

  static const String _retryingMessage = 'Retrying…';

  /// Every step's current state, emitted on each change.
  Stream<List<InitStepState>> get progress => _progress.stream;

  /// A snapshot of every step's current state.
  List<InitStepState> get steps => List<InitStepState>.unmodifiable(_steps);

  /// Begins running the plan. Calling it again has no effect.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(_runAll());
  }

  /// Re-runs the blocked step, after the rider has acted. Ignored when no
  /// step is blocked.
  void retry() {
    final signal = _retrySignal;
    if (signal != null && !signal.isCompleted) signal.complete();
  }

  /// Stops all work and releases resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    retry();
    final attempt = _attempt;
    if (attempt != null && !attempt.isCompleted) {
      attempt.complete(_Outcome.failed);
    }
    await _active?.cancel();
    await _progress.close();
  }

  Future<void> _runAll() async {
    for (var i = 0; i < _tasks.length && !_disposed; i++) {
      while (!_disposed) {
        final outcome = await _runOnce(i);
        if (outcome == _Outcome.done || _disposed) break;
        if (outcome == _Outcome.blocked) {
          final signal = Completer<void>();
          _retrySignal = signal;
          await signal.future;
          _retrySignal = null;
        } else {
          await Future<void>.delayed(retryDelay);
        }
      }
    }
  }

  /// Runs task [index] until it reports done or blocked, or fails.
  Future<_Outcome> _runOnce(int index) async {
    final attempt = Completer<_Outcome>();
    _attempt = attempt;

    void finish(_Outcome outcome) {
      if (!attempt.isCompleted) attempt.complete(outcome);
    }

    _update(index, const InitTaskUpdate.running());
    _active = _tasks[index].run().listen(
      (update) {
        _update(index, update);
        if (update.phase == InitStepPhase.done) finish(_Outcome.done);
        if (update.phase == InitStepPhase.blocked) finish(_Outcome.blocked);
      },
      onError: (Object error, StackTrace stack) {
        developer.log(
          'Initialization step "${_tasks[index].id}" failed; retrying.',
          name: 'RideInitializer',
          error: error,
          stackTrace: stack,
        );
        _update(index, const InitTaskUpdate.waiting(_retryingMessage));
        finish(_Outcome.failed);
      },
      // A task that ends without reporting done has not finished its work.
      onDone: () => finish(_Outcome.failed),
    );

    final outcome = await attempt.future;
    final active = _active;
    _active = null;
    _attempt = null;
    await active?.cancel();
    return outcome;
  }

  void _update(int index, InitTaskUpdate update) {
    if (_disposed) return;
    _steps[index] = _steps[index]._apply(update);
    _progress.add(steps);
  }
}

enum _Outcome { done, blocked, failed }
