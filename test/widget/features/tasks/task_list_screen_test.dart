// Widget tests for TaskListScreen (S-03). Controls taskListProvider(spaceId)
// — a StreamProvider.autoDispose.family — via the standard Riverpod family
// override syntax (`overrideWith((ref, spaceId) => stream)`), mirroring
// home_screen_test.dart's single-pump-after-pumpWidget pattern for
// stream-backed providers. Also overrides deleteTaskProvider, addTaskProvider,
// and updateTaskProvider with fake AutoDisposeAsyncNotifier subclasses
// (mirroring settings_screen_test.dart's _FakeSignOutNotifier /
// create_space_screen_test.dart's _FakeCreateSpaceNotifier pattern) so
// opening TaskDetailSheet (Edit / FAB) and the Remove flow never reach real
// Firestore. Never touches real Firebase or Firestore.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/task_detail_sheet.dart';
import 'package:shared_tasks/features/tasks/presentation/task_list_screen.dart';

const _spaceId = 'space-1';

Task _task(
  String id, {
  String title = 'Task',
  String? notes,
  TaskStatus status = TaskStatus.todo,
}) {
  return Task(
    id: id,
    spaceId: _spaceId,
    title: title,
    notes: notes,
    status: status,
    createdBy: 'uid-1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

/// A controllable stand-in for [DeleteTaskController]. Records every call so
/// tests can verify the real delete fires (or doesn't) without touching
/// Firestore.
class _FakeDeleteTaskController extends DeleteTaskController {
  int deleteTaskCallCount = 0;
  String? lastSpaceId;
  String? lastTaskId;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> deleteTask({required String spaceId, required String taskId}) async {
    deleteTaskCallCount++;
    lastSpaceId = spaceId;
    lastTaskId = taskId;
  }
}

/// A controllable stand-in for [AddTaskController]. Records every call —
/// used to verify the stub menu actions never trigger a real add.
class _FakeAddTaskController extends AddTaskController {
  int addTaskCallCount = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> addTask({
    required String spaceId,
    required String title,
    String? notes,
  }) async {
    addTaskCallCount++;
  }
}

/// A controllable stand-in for [UpdateTaskController]. Records every call —
/// used to verify the stub menu actions never trigger a real update.
class _FakeUpdateTaskController extends UpdateTaskController {
  int updateTaskCallCount = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> updateTask({
    required String spaceId,
    required String taskId,
    required String title,
    String? notes,
  }) async {
    updateTaskCallCount++;
  }
}

class _Fakes {
  _Fakes()
    : deleteTaskController = _FakeDeleteTaskController(),
      addTaskController = _FakeAddTaskController(),
      updateTaskController = _FakeUpdateTaskController();

  final _FakeDeleteTaskController deleteTaskController;
  final _FakeAddTaskController addTaskController;
  final _FakeUpdateTaskController updateTaskController;
}

/// Pumps [TaskListScreen] with `taskListProvider(spaceId)` overridden to
/// [stream], and delete/add/update controllers replaced with fakes.
Future<_Fakes> _pumpScreen(
  WidgetTester tester, {
  required Stream<List<Task>> stream,
}) async {
  final fakes = _Fakes();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskListProvider.overrideWith((ref, spaceId) => stream),
        deleteTaskProvider.overrideWith(() => fakes.deleteTaskController),
        addTaskProvider.overrideWith(() => fakes.addTaskController),
        updateTaskProvider.overrideWith(() => fakes.updateTaskController),
      ],
      child: const MaterialApp(home: TaskListScreen(spaceId: _spaceId)),
    ),
  );
  await tester.pump();

  return fakes;
}

/// Opens the three-dot menu for the row containing [taskTitle] and taps the
/// item labeled [itemLabel].
Future<void> _tapMenuItem(
  WidgetTester tester, {
  required String taskTitle,
  required String itemLabel,
}) async {
  final row = find.ancestor(
    of: find.text(taskTitle),
    matching: find.byType(ListTile),
  );
  final menuButton = find.descendant(
    of: row,
    matching: find.byType(PopupMenuButton<String>),
  );
  await tester.tap(menuButton);
  await tester.pumpAndSettle();

  await tester.tap(find.text(itemLabel).last);
  await tester.pumpAndSettle();
}

void main() {
  group('TaskListScreen — loading state', () {
    testWidgets(
        'shows a CircularProgressIndicator and no task content while '
        'taskListProvider has not yet emitted', (tester) async {
      await _pumpScreen(tester, stream: const Stream<List<Task>>.empty());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });
  });

  group('TaskListScreen — error state', () {
    testWidgets('shows the inline error text when the stream emits an error',
        (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream<List<Task>>.error(Exception('firestore boom')),
      );

      expect(
        find.text('Something went wrong loading tasks.'),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('TaskListScreen — empty state', () {
    testWidgets('shows "No tasks yet" when the list is empty', (tester) async {
      await _pumpScreen(tester, stream: Stream.value(const []));

      expect(find.text('No tasks yet'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });
  });

  group('TaskListScreen — active vs completed grouping', () {
    testWidgets(
        'active tasks render outside any ExpansionTile, done tasks render '
        'inside a collapsed "Completed (N)" ExpansionTile', (tester) async {
      final todo = _task('t1', title: 'Todo task');
      final inProgress = _task(
        't2',
        title: 'In progress task',
        status: TaskStatus.inProgress,
      );
      final done = _task('t3', title: 'Done task', status: TaskStatus.done);
      await _pumpScreen(
        tester,
        stream: Stream.value([todo, inProgress, done]),
      );

      expect(find.text('Todo task'), findsOneWidget);
      expect(find.text('In progress task'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);

      // The done task's own text is not visible until the tile is expanded.
      expect(find.text('Done task'), findsNothing);

      final expansionTile = find.byType(ExpansionTile);
      expect(
        find.descendant(of: expansionTile, matching: find.text('Todo task')),
        findsNothing,
        reason: 'an active task must not render inside the ExpansionTile',
      );

      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Done task'), findsOneWidget);
    });

    testWidgets('no ExpansionTile is shown when there are no completed tasks',
        (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Todo task')]),
      );

      expect(find.byType(ExpansionTile), findsNothing);
    });
  });

  group('TaskListScreen — three-dot menu presence', () {
    testWidgets('a PopupMenuButton exists per row, with no Dismissible '
        'anywhere (swipe gesture removed)', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Task one'), _task('t2', title: 'Task two')]),
      );

      expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
      expect(find.byType(Dismissible), findsNothing);
    });
  });

  group('TaskListScreen — Edit menu item', () {
    testWidgets('tapping three-dot then Edit opens TaskDetailSheet '
        'pre-filled for that task', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Buy milk', notes: 'Whole milk'),
        ]),
      );

      await _tapMenuItem(tester, taskTitle: 'Buy milk', itemLabel: 'Edit');

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.text('Edit task'), findsOneWidget);
    });
  });

  group('TaskListScreen — Remove, non-in-progress task', () {
    testWidgets('immediately hides the task with no AlertDialog and shows '
        'the undo SnackBar with the task title', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Buy milk')]),
      );

      await _tapMenuItem(tester, taskTitle: 'Buy milk', itemLabel: 'Remove');

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Buy milk'), findsNothing);
      expect(find.text('"Buy milk" deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('a done task is also removed without confirmation',
        (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Wash dishes', status: TaskStatus.done),
        ]),
      );

      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();

      await _tapMenuItem(
        tester,
        taskTitle: 'Wash dishes',
        itemLabel: 'Remove',
      );

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('"Wash dishes" deleted'), findsOneWidget);
    });
  });

  group('TaskListScreen — Remove, in-progress task confirmation', () {
    testWidgets('shows the confirmation AlertDialog first', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Mow lawn', status: TaskStatus.inProgress),
        ]),
      );

      await _tapMenuItem(tester, taskTitle: 'Mow lawn', itemLabel: 'Remove');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete in-progress task?'), findsOneWidget);
    });

    testWidgets('tapping Cancel leaves the task visible and shows no undo '
        'snackbar', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Mow lawn', status: TaskStatus.inProgress),
        ]),
      );

      await _tapMenuItem(tester, taskTitle: 'Mow lawn', itemLabel: 'Remove');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Mow lawn'), findsOneWidget);
      expect(find.text('"Mow lawn" deleted'), findsNothing);
    });

    testWidgets('tapping Delete proceeds to hide the task and show the undo '
        'snackbar, same as the non-in-progress path', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Mow lawn', status: TaskStatus.inProgress),
        ]),
      );

      await _tapMenuItem(tester, taskTitle: 'Mow lawn', itemLabel: 'Remove');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Mow lawn'), findsNothing);
      expect(find.text('"Mow lawn" deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });
  });

  group('TaskListScreen — Undo restores the task', () {
    testWidgets('tapping Undo synchronously restores visibility and never '
        'calls the real delete', (tester) async {
      final fakes = await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Buy milk')]),
      );

      await _tapMenuItem(tester, taskTitle: 'Buy milk', itemLabel: 'Remove');
      expect(find.text('Buy milk'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(find.text('Buy milk'), findsOneWidget);
      expect(fakes.deleteTaskController.deleteTaskCallCount, 0);
    });
  });

  group('TaskListScreen — auto-delete after the undo window elapses', () {
    testWidgets('fast-forwarding 6 seconds without tapping Undo calls the '
        'real delete exactly once with the correct spaceId/taskId',
        (tester) async {
      final fakes = await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Buy milk')]),
      );

      await _tapMenuItem(tester, taskTitle: 'Buy milk', itemLabel: 'Remove');
      expect(fakes.deleteTaskController.deleteTaskCallCount, 0);

      // Fast-forward the fake clock past the 5-second undo window. The
      // SnackBar is shown with `persist: false` specifically so this real
      // timeout fires and self-closes with SnackBarClosedReason.timeout —
      // Flutter's SnackBar otherwise defaults `persist` to true whenever an
      // `action` is supplied (see snack_bar.dart — `persist = persist ??
      // action != null`), which would silently disable the duration-based
      // auto-dismiss entirely. No manual ScaffoldMessenger nudge needed
      // here — this proves the real timer, not a simulated one.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(fakes.deleteTaskController.deleteTaskCallCount, 1);
      expect(fakes.deleteTaskController.lastSpaceId, _spaceId);
      expect(fakes.deleteTaskController.lastTaskId, 't1');
    });
  });

  group('TaskListScreen — Assign / Mark done stubs', () {
    testWidgets('tapping Assign shows a "coming soon" SnackBar and calls no '
        'controller', (tester) async {
      final fakes = await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Buy milk')]),
      );

      await _tapMenuItem(tester, taskTitle: 'Buy milk', itemLabel: 'Assign');

      expect(find.text('Assign — coming soon'), findsOneWidget);
      expect(fakes.deleteTaskController.deleteTaskCallCount, 0);
      expect(fakes.addTaskController.addTaskCallCount, 0);
      expect(fakes.updateTaskController.updateTaskCallCount, 0);
    });

    testWidgets('tapping Mark done shows a "coming soon" SnackBar and calls '
        'no controller', (tester) async {
      final fakes = await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Buy milk')]),
      );

      await _tapMenuItem(
        tester,
        taskTitle: 'Buy milk',
        itemLabel: 'Mark done',
      );

      expect(find.text('Mark done — coming soon'), findsOneWidget);
      expect(fakes.deleteTaskController.deleteTaskCallCount, 0);
      expect(fakes.addTaskController.addTaskCallCount, 0);
      expect(fakes.updateTaskController.updateTaskCallCount, 0);
    });
  });

  group('TaskListScreen — FAB', () {
    testWidgets('the FAB is present', (tester) async {
      await _pumpScreen(tester, stream: Stream.value(const []));

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('tapping the FAB opens TaskDetailSheet in add mode',
        (tester) async {
      await _pumpScreen(tester, stream: Stream.value(const []));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
    });
  });
}
