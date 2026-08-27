import 'package:shared_tasks/core/errors/failure.dart';

/// Outcome of a repository operation — either a [Success] with data or a
/// [Failure] with an [AppFailure].
///
/// Repositories return `Result<T>` instead of throwing. Callers exhaustively
/// pattern-match with a `switch`:
///
/// ```dart
/// final result = await repository.addTask(task);
/// switch (result) {
///   case Success(:final data):
///     // handle data
///   case Failure(:final failure):
///     // handle failure
/// }
/// ```
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;
}
