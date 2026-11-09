/// Where an initialization step currently stands.
enum InitStepPhase {
  /// Not started yet.
  pending,

  /// Working.
  running,

  /// Waiting on something outside the app's control (GPS signal, network)
  /// and will continue by itself.
  waiting,

  /// Cannot continue until the rider acts (see [InitBlocker]).
  blocked,

  /// Finished for real.
  done,
}

/// A rider action that unblocks initialization.
enum InitBlocker {
  /// Location access was declined; the system prompt can be shown again.
  locationPermissionDenied,

  /// Location access was declined permanently; only Settings can grant it.
  locationPermissionDeniedForever,
}

/// A progress report from an [InitTask].
class InitTaskUpdate {
  const InitTaskUpdate._(this.phase, {this.message, this.blocker});

  /// The task is working.
  const InitTaskUpdate.running() : this._(InitStepPhase.running);

  /// The task is waiting on an external condition and will resume by itself.
  const InitTaskUpdate.waiting(String message)
      : this._(InitStepPhase.waiting, message: message);

  /// The task needs the rider to act before it can be retried.
  const InitTaskUpdate.blocked(InitBlocker blocker)
      : this._(InitStepPhase.blocked, blocker: blocker);

  /// The task finished.
  const InitTaskUpdate.done() : this._(InitStepPhase.done);

  final InitStepPhase phase;

  /// Short status text for [InitStepPhase.waiting].
  final String? message;

  /// What the rider must do, for [InitStepPhase.blocked].
  final InitBlocker? blocker;
}

/// One unit of ride initialization, such as acquiring a GPS fix.
///
/// Tasks are independent and composable: a ride's initialization plan is just
/// an ordered list of tasks, so a future milestone adds a step by adding a
/// task, without touching the engine or the screen.
abstract interface class InitTask {
  /// Stable identifier, unique within a plan.
  String get id;

  /// Rider-facing label, e.g. "GPS Locked".
  String get label;

  /// Performs the task, reporting progress. The stream must emit
  /// [InitTaskUpdate.done] only when the work has genuinely completed, or
  /// [InitTaskUpdate.blocked] when the rider has to act. Errors are retried by
  /// the engine.
  Stream<InitTaskUpdate> run();
}
