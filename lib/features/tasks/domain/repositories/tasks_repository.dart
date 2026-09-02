import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';

/// Abstract tasks interface — `data/` provides the Firestore-backed
/// implementation, `presentation/` only ever talks to this.
abstract interface class TasksRepository {
  /// Emits every task in [spaceId]'s `tasks` subcollection, and re-emits on
  /// every realtime change.
  ///
  /// Not wrapped in [Result] — this is a stream, matching the precedent of
  /// [HomeRepository.watchUserSpaces] (only Future-returning repository
  /// methods use `Result<T>` in this codebase).
  Stream<List<Task>> watchTasks(String spaceId);

  /// Creates a new task in [spaceId], defaulting to `TaskStatus.todo`.
  Future<Result<void>> addTask({
    required String spaceId,
    required String title,
    String? notes,
    required String createdBy,
  });

  /// Updates [taskId]'s `title` and `notes`.
  Future<Result<void>> updateTask({
    required String spaceId,
    required String taskId,
    required String title,
    String? notes,
  });

  /// Deletes [taskId] from [spaceId].
  Future<Result<void>> deleteTask({
    required String spaceId,
    required String taskId,
  });
}
