import 'package:flutter/foundation.dart';

import 'failure.dart';

/// A functional result type used across the data and domain layers.
///
/// Instead of throwing, repositories and use cases return a [Result], forcing
/// callers to handle both the success and the [Failure] paths explicitly.
@immutable
sealed class Result<T> {
  const Result();

  /// Whether this result represents a success.
  bool get isSuccess => this is Success<T>;

  /// The value if successful, otherwise `null`.
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failed<T>() => null,
      };

  /// Folds both branches into a single value of type [R].
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      Failed<T>(:final failure) => onFailure(failure),
    };
  }
}

/// A successful [Result] carrying a [value].
final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

/// A failed [Result] carrying a [failure].
final class Failed<T> extends Result<T> {
  const Failed(this.failure);
  final Failure failure;
}
