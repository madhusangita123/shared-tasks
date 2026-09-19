import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/core/providers/connectivity_provider.dart';
import 'package:shared_tasks/core/providers/firebase_providers.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/notifications/presentation/providers/foreground_notification_provider.dart';
import 'package:shared_tasks/features/tasks/data/tasks_remote_datasource.dart';
import 'package:shared_tasks/features/tasks/data/tasks_repository_impl.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/domain/repositories/tasks_repository.dart';

/// Blocks a task mutation while the device is known to be offline — issue
/// #11 (US-08). Returns `true` (and shows a [SnackBar] via
/// [scaffoldMessengerKeyProvider], the same global key
/// [foregroundNotificationProvider] uses to reach the app's
/// [ScaffoldMessenger] from outside the widget tree) when the caller
/// should stop and not touch the repository.
///
/// Each call site still sets its own `state = AsyncError(const
/// NetworkFailure(), ...)` when this returns `true` — found via on-device
/// testing that leaving `state` untouched here breaks the optimistic UI
/// on the caller's own side: `_AssignToSectionState`/`_StatusSectionState`
/// (issues #9/#10) only roll their optimistic selection back on
/// `next.hasError`, so an offline-blocked write that never changes `state`
/// leaves the sheet showing whatever the user just tapped as if it were
/// selected — silently wrong until the sheet is closed and reopened, even
/// though the SnackBar did fire. Setting `state` here instead reuses that
/// same already-proven rollback path rather than needing a second one.
///
/// Checks [isOnlineProvider].valueOrNull for exactly `false` — not merely
/// "not true". A `null`/loading/error connectivity state is indeterminate,
/// and blocking a write on an indeterminate signal would be worse than
/// occasionally letting a genuinely-offline write through to Firestore's
/// own normal (queue-and-sync) handling, so this fails open rather than
/// closed.
///
/// Set [announce] to `false` when the caller surfaces the resulting
/// [NetworkFailure] itself, so the user isn't told twice about one blocked
/// write. Only [AddTaskController] does: it hands the failure back to
/// [InlineAddTaskRow], which shows its own SnackBar. Every other controller
/// relies on the global SnackBar here, because nothing downstream of them
/// reports the failure to the user.
bool _blockIfOffline(Ref ref, {bool announce = true}) {
  if (ref.read(isOnlineProvider).valueOrNull != false) return false;

  if (announce) {
    final messengerState = ref.read(scaffoldMessengerKeyProvider).currentState;
    messengerState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("You're offline — changes can't be saved right now"),
        ),
      );
  }
  return true;
}

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

  /// Returns the [AppFailure] that stopped this particular write, or `null`
  /// if it succeeded.
  ///
  /// Callers that need to react to *their own* call's outcome must use this
  /// return value rather than reading [addTaskProvider]'s state once the
  /// future resolves. The provider is shared, and [InlineAddTaskRow] puts two
  /// add rows on screen at once — a second submit overwrites `state` before
  /// the first caller resumes, so a state read there can attribute one row's
  /// result to the other (clearing text the user still needs, or blaming the
  /// wrong row for a failure).
  Future<AppFailure?> addTask({
    required String spaceId,
    required String title,
    String? notes,
  }) async {
    // announce: false — the returned failure is reported by whoever called
    // this. Letting the global SnackBar fire too would stack two messages
    // for one blocked add.
    if (_blockIfOffline(ref, announce: false)) {
      const failure = NetworkFailure();
      state = AsyncError<void>(failure, StackTrace.current);
      return failure;
    }

    final createdBy = ref.read(authStateProvider).valueOrNull?.id;
    if (createdBy == null) {
      const failure = AuthFailure('You must be signed in.');
      state = AsyncError<void>(failure, StackTrace.current);
      return failure;
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
    switch (result) {
      case Success():
        state = const AsyncData(null);
        return null;
      case Failure(:final failure):
        state = AsyncError<void>(failure, StackTrace.current);
        return failure;
    }
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
    if (_blockIfOffline(ref)) {
      state = AsyncError<void>(const NetworkFailure(), StackTrace.current);
      return;
    }

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
    if (_blockIfOffline(ref)) {
      state = AsyncError<void>(const NetworkFailure(), StackTrace.current);
      return;
    }

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
    if (_blockIfOffline(ref)) {
      state = AsyncError<void>(const NetworkFailure(), StackTrace.current);
      return;
    }

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

/// Drives the status-changing controls on [TaskListScreen] (the row's own
/// status icon, and the three-dot menu's "Mark done") and
/// [TaskDetailSheet]'s status selector — issue #10.
class UpdateStatusController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> updateStatus({
    required String spaceId,
    required String taskId,
    required TaskStatus status,
  }) async {
    if (_blockIfOffline(ref)) {
      state = AsyncError<void>(const NetworkFailure(), StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    final result = await ref
        .read(tasksRepositoryProvider)
        .updateStatus(spaceId: spaceId, taskId: taskId, status: status);
    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final failure) => AsyncError<void>(failure, StackTrace.current),
    };
  }
}

final updateStatusProvider =
    AutoDisposeAsyncNotifierProvider<UpdateStatusController, void>(
      UpdateStatusController.new,
    );
