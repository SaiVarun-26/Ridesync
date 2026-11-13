import 'package:flutter/foundation.dart';

/// Domain-level error type. Repositories convert low-level exceptions
/// (Firebase, network, platform) into a [Failure] so the UI layer never sees
/// raw exceptions and can render a stable, user-facing [message].
@immutable
sealed class Failure {
  const Failure(this.message, {this.cause});

  /// A concise, user-safe description of what went wrong.
  final String message;

  /// The underlying error, retained for logging only — never shown to users.
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

/// Connectivity or transport-level problem.
class NetworkFailure extends Failure {
  const NetworkFailure({
    String message = 'No connection. Check your network and try again.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Authentication/session problem.
class AuthFailure extends Failure {
  const AuthFailure({
    String message = 'Could not sign you in. Please try again.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Requested resource (room, ride) does not exist.
class NotFoundFailure extends Failure {
  const NotFoundFailure({String message = 'Not found.', Object? cause})
    : super(message, cause: cause);
}

/// The room no longer takes new riders because the host has ended the ride.
class RoomLockedFailure extends Failure {
  const RoomLockedFailure({
    String message = 'This ride has finished and is no longer taking riders.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// A conflicting write, e.g. a color was claimed by someone else first.
class ConflictFailure extends Failure {
  const ConflictFailure({
    String message = 'That option was just taken. Pick another.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// A device permission (location) was denied.
class PermissionFailure extends Failure {
  const PermissionFailure({
    String message = 'Permission denied.',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Anything not covered above.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    String message = 'Something went wrong. Please try again.',
    Object? cause,
  }) : super(message, cause: cause);
}
