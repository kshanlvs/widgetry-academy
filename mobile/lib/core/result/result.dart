import 'package:widgetry_academy/core/error/failures.dart';

/// Either a value or a [Failure]. Use cases and repositories return this instead of throwing.
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onSuccess) => switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Err<T>(:final failure) => onFailure(failure),
      };

  bool get isSuccess => this is Success<T>;
  T? get valueOrNull => switch (this) { Success<T>(:final value) => value, Err<T>() => null };
  Failure? get failureOrNull => switch (this) { Success<T>() => null, Err<T>(:final failure) => failure };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

/// Unit value for operations that return nothing.
final class Unit {
  const Unit._();
}

const unit = Unit._();
