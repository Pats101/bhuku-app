import 'failure.dart';

/// A lightweight result type: either a success value [Ok] or a [Failure] [Err].
///
/// We use this instead of exceptions for predictable error flow across the
/// repository boundary. Pattern-match with a `switch` to handle both arms:
///
/// ```dart
/// switch (result) {
///   case Ok(:final value): useIt(value);
///   case Err(:final failure): showMessage(failure.message);
/// }
/// ```
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Transform the success value, leaving failures untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Ok(transform(value)),
        Err<T>(:final failure) => Err(failure),
      };

  /// Returns the value, or [fallback] on failure.
  T getOrElse(T fallback) => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => fallback,
      };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
