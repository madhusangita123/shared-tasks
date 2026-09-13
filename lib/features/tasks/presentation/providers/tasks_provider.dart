import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/core/providers/firebase_providers.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/tasks/data/tasks_remote_datasource.dart';
import 'package:shared_tasks/features/tasks/data/tasks_repository_impl.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/repositories/tasks_repository.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepositoryImpl(
    datasource: TasksRemoteDatasource(firestore: ref.watch(firestoreProvider)),
  );
});

/// Emits every task in `spaceId`'s task list, re-emitting on every realtime
/// change. Matches docs/ARCHITECTURE.md's documented example exactly.
final taskListProvider = StreamProvider.autoDispose.family<List<Task>, String>(
  (ref, spaceId) => ref.watch(tasksRepositoryProvider).watchTasks(spaceId),
);

/// Drives the "Add" button on [TaskDetailSheet] in add mode.
class AddTaskController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> addTask({
    required String spaceId,
    required String title,
    String? notes,
  }) async {
    final createdBy = ref.read(authStateProvider).valueOrNull?.id;
    if (createdBy == null) {
      state = AsyncError<void>(
        const AuthFailure('You must be signed in.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    final result = await ref
        .read(tasksRepositoryProvider)
        .addTask(
          spaceId: spaceId,
          title: title,
          notes: notes,
          createdBy: createdBy,
        );
    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final failure) => AsyncError<void>(failure, StackTrace.current),
    };
  }
}

final addTaskProvider = AutoDisposeAsyncNotifierProvider<AddTaskController, void>(
  AddTaskController.new,
);

/// Drives the "Save" button on [TaskDetailSheet] in edit mode.
class UpdateTaskController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> updateTask({
    required String spaceId,
    required String taskId,
    required String title,
    String? notes,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(tasksRepositoryProvider)
        .updateTask(spaceId: spaceId, taskId: taskId, title: title, notes: notes);
    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final failure) => AsyncError<void>(failure, StackTrace.current),
    };
  }
}

final updateTaskProvider =
    AutoDisposeAsyncNotifierProvider<UpdateTaskController, void>(
      UpdateTaskController.new,
    );

/// Drives the swipe-to-delete flow on [TaskListScreen].
class DeleteTaskController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> deleteTask({
    required String spaceId,
    required String taskId,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(tasksRepositoryProvider)
        .deleteTask(spaceId: spaceId, taskId: taskId);
    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final failure) => AsyncError<void>(failure, StackTrace.current),
    };
  }
}

final deleteTaskProvider =
    AutoDisposeAsyncNotifierProvider<DeleteTaskController, void>(
      DeleteTaskController.new,
    );

/// Drives the "Assign to" section on [TaskDetailSheet] — issue #9. A tap on
/// an already-assigned member's avatar passes `null` to unassign; any other
/// avatar (including the current user's own, for "assign to me") passes
/// that member's uid.
///
/// [assignTask]'s own signature is unchanged by issue #12 — callers still
/// only ever pass `assigneeUid`. `assignedByUid` (who performed the
/// assignment, for the `onTaskAssigned` Cloud Function's notification
/// copy) is derived here from the signed-in user, the same way
/// [AddTaskController.addTask] derives `createdBy`, rather than being
/// threaded through from the UI — the signed-in user performing the tap
/// *is* the assigner, so there's nothing for a caller to supply. Passed as
/// `null` on unassign, matching `assigneeUid` — there's no assigner for a
/// non-assignment.
class AssignTaskController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> assignTask({
    required String spaceId,
    required String taskId,
    required String? assigneeUid,
  }) async {
    final assignedByUid = assigneeUid == null
        ? null
        : ref.read(authStateProvider).valueOrNull?.id;

    state = const AsyncLoading();
    final result = await ref
        .read(tasksRepositoryProvider)
        .assignTask(
          spaceId: spaceId,
          taskId: taskId,
          assigneeUid: assigneeUid,
          assignedByUid: assignedByUid,
        );
    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final failure) => AsyncError<void>(failure, StackTrace.current),
    };
  }
}

final assignTaskProvider =
    AutoDisposeAsyncNotifierProvider<AssignTaskController, void>(
      AssignTaskController.new,
    );
