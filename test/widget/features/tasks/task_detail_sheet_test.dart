// Widget tests for TaskDetailSheet (S-04). Overrides addTaskProvider and
// updateTaskProvider with fake AutoDisposeAsyncNotifier subclasses
// (mirroring create_space_screen_test.dart's _FakeCreateSpaceNotifier
// pattern — pending/initialError constructor knobs, call-count +
// last-args recording fields) so every state (pristine, loading, error,
// success) can be driven without touching real Firebase or Firestore.
//
// The sheet is pumped via a real showModalBottomSheet call triggered by a
// button in a tiny harness widget (there's no existing Navigator.pop()
// precedent elsewhere in this codebase's tests), so the "success pops the
// sheet" behavior can be verified by asserting the sheet's content is no
// longer found after the fake notifier's state flips to AsyncData and
// pumpAndSettle() runs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/task_detail_sheet.dart';

const _spaceId = 'space-1';

Task _task({
  String id = 'task-1',
  String title = 'Buy milk',
  String? notes = 'Whole milk',
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

/// A controllable stand-in for [AddTaskController].
///
/// - [initialError] makes the notifier's initial state `AsyncError` (as if
///   a previous add attempt failed).
/// - [pending] makes `build()` return a `Future` that never resolves during
///   the test, so the initial state stays `AsyncLoading` — simulating an
///   add attempt in flight.
/// [addTask] always flips `state` through `AsyncLoading` to
/// `AsyncData(null)` the way the real notifier would on a successful add,
/// so the sheet's pop-on-success behavior can be exercised.
class _FakeAddTaskController extends AddTaskController {
  _FakeAddTaskController({this.initialError, this.pending = false});

  final Object? initialError;
  final bool pending;

  int addTaskCallCount = 0;
  String? lastSpaceId;
  String? lastTitle;
  String? lastNotes;

  @override
  FutureOr<void> build() {
    if (initialError != null) {
      throw initialError!;
    }
    if (pending) {
      return Completer<void>().future;
    }
    return null;
  }

  @override
  Future<void> addTask({
    required String spaceId,
    required String title,
    String? notes,
  }) async {
    addTaskCallCount++;
    lastSpaceId = spaceId;
    lastTitle = title;
    lastNotes = notes;
    state = const AsyncLoading();
    state = const AsyncData(null);
  }
}

/// A controllable stand-in for [UpdateTaskController]. Same knobs as
/// [_FakeAddTaskController], plus a `taskId` recording field.
class _FakeUpdateTaskController extends UpdateTaskController {
  _FakeUpdateTaskController({this.initialError, this.pending = false});

  final Object? initialError;
  final bool pending;

  int updateTaskCallCount = 0;
  String? lastSpaceId;
  String? lastTaskId;
  String? lastTitle;
  String? lastNotes;

  @override
  FutureOr<void> build() {
    if (initialError != null) {
      throw initialError!;
    }
    if (pending) {
      return Completer<void>().future;
    }
    return null;
  }

  @override
  Future<void> updateTask({
    required String spaceId,
    required String taskId,
    required String title,
    String? notes,
  }) async {
    updateTaskCallCount++;
    lastSpaceId = spaceId;
    lastTaskId = taskId;
    lastTitle = title;
    lastNotes = notes;
    state = const AsyncLoading();
    state = const AsyncData(null);
  }
}

/// Pumps a tiny harness (a button that opens [TaskDetailSheet] via a real
/// `showModalBottomSheet`) with [addTaskProvider] and [updateTaskProvider]
/// overridden to fakes, then taps the button so the sheet is showing.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required _FakeAddTaskController addController,
  required _FakeUpdateTaskController updateController,
  Task? task,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addTaskProvider.overrideWith(() => addController),
        updateTaskProvider.overrideWith(() => updateController),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      TaskDetailSheet(spaceId: _spaceId, task: task),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Not pumpAndSettle() — a pending (AsyncLoading) fake controller drives
  // the AppButton's indeterminate CircularProgressIndicator, which never
  // settles. A single bounded pump is enough to finish the bottom sheet's
  // own entrance transition.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder get _titleField => find.byType(TextField).first;
Finder get _notesField => find.byType(TextField).at(1);

void main() {
  group('TaskDetailSheet — add mode, pristine state', () {
    testWidgets('fields start empty, title is "Add task", button is "Add"',
        (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
      );

      expect(find.text('Add task'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(tester.widget<TextField>(_titleField).controller!.text, '');
      expect(tester.widget<TextField>(_notesField).controller!.text, '');
    });
  });

  group('TaskDetailSheet — add mode, validation', () {
    testWidgets('submitting an empty title shows a validation error and '
        'does not call addTask', (tester) async {
      final addController = _FakeAddTaskController();
      await _pumpSheet(
        tester,
        addController: addController,
        updateController: _FakeUpdateTaskController(),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(find.text('Title is required'), findsOneWidget);
      expect(addController.addTaskCallCount, 0);
    });

    testWidgets('submitting a title over taskTitleMaxLength shows a '
        'validation error and does not call addTask', (tester) async {
      final addController = _FakeAddTaskController();
      await _pumpSheet(
        tester,
        addController: addController,
        updateController: _FakeUpdateTaskController(),
      );

      // Bypass the TextField's own maxLength input formatter (which would
      // silently clamp text entered via tester.enterText) by mutating the
      // controller directly, so the sheet's own over-length validation
      // branch can be reached and asserted on.
      final titleField = tester.widget<TextField>(_titleField);
      titleField.controller!.text =
          'a' * (AppConstants.taskTitleMaxLength + 1);
      await tester.pump();

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(
        find.text(
          'Title must be ${AppConstants.taskTitleMaxLength} characters or '
          'fewer',
        ),
        findsOneWidget,
      );
      expect(addController.addTaskCallCount, 0);
    });

    testWidgets('a valid title with notes calls addTask with the correct '
        'spaceId/trimmed-title/notes', (tester) async {
      final addController = _FakeAddTaskController();
      await _pumpSheet(
        tester,
        addController: addController,
        updateController: _FakeUpdateTaskController(),
      );

      await tester.enterText(_titleField, '  Buy milk  ');
      await tester.enterText(_notesField, '  Whole milk  ');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(addController.addTaskCallCount, 1);
      expect(addController.lastSpaceId, _spaceId);
      expect(addController.lastTitle, 'Buy milk');
      expect(addController.lastNotes, 'Whole milk');
    });

    testWidgets('empty notes become null', (tester) async {
      final addController = _FakeAddTaskController();
      await _pumpSheet(
        tester,
        addController: addController,
        updateController: _FakeUpdateTaskController(),
      );

      await tester.enterText(_titleField, 'Buy milk');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(addController.addTaskCallCount, 1);
      expect(addController.lastNotes, isNull);
    });

    testWidgets('whitespace-only notes become null', (tester) async {
      final addController = _FakeAddTaskController();
      await _pumpSheet(
        tester,
        addController: addController,
        updateController: _FakeUpdateTaskController(),
      );

      await tester.enterText(_titleField, 'Buy milk');
      await tester.enterText(_notesField, '   ');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(addController.addTaskCallCount, 1);
      expect(addController.lastNotes, isNull);
    });
  });

  group('TaskDetailSheet — edit mode, pristine state', () {
    testWidgets('fields are pre-filled, title is "Edit task", button is '
        '"Save"', (tester) async {
      final task = _task(title: 'Buy milk', notes: 'Whole milk');
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: task,
      );

      expect(find.text('Edit task'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(tester.widget<TextField>(_titleField).controller!.text, 'Buy milk');
      expect(
        tester.widget<TextField>(_notesField).controller!.text,
        'Whole milk',
      );
    });
  });

  group('TaskDetailSheet — edit mode, submit', () {
    testWidgets('calls updateTask with the correct spaceId/taskId/'
        'trimmed-title/notes', (tester) async {
      final task = _task(id: 'task-42', title: 'Buy milk', notes: 'Old notes');
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: updateController,
        task: task,
      );

      await tester.enterText(_titleField, '  Buy oat milk  ');
      await tester.enterText(_notesField, '  From the co-op  ');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(updateController.updateTaskCallCount, 1);
      expect(updateController.lastSpaceId, _spaceId);
      expect(updateController.lastTaskId, 'task-42');
      expect(updateController.lastTitle, 'Buy oat milk');
      expect(updateController.lastNotes, 'From the co-op');
    });
  });

  group('TaskDetailSheet — loading state', () {
    testWidgets("add mode: the button's isLoading is true while "
        'addTaskProvider is AsyncLoading', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(pending: true),
        updateController: _FakeUpdateTaskController(),
      );

      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isTrue);
    });

    testWidgets("edit mode: the button's isLoading is true while "
        'updateTaskProvider is AsyncLoading', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(pending: true),
        task: _task(),
      );

      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isTrue);
    });
  });

  group('TaskDetailSheet — error state', () {
    testWidgets('add mode: shows an AppFailure\'s own message inline',
        (tester) async {
      const failure = NetworkFailure();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(initialError: failure),
        updateController: _FakeUpdateTaskController(),
      );

      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets('add mode: falls back to "Could not add task. Try again." '
        'for a non-AppFailure error', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(initialError: Exception('boom')),
        updateController: _FakeUpdateTaskController(),
      );

      expect(find.text('Could not add task. Try again.'), findsOneWidget);
    });

    testWidgets("edit mode: shows an AppFailure's own message inline",
        (tester) async {
      const failure = NetworkFailure();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(initialError: failure),
        task: _task(),
      );

      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets('edit mode: falls back to "Could not save task. Try '
        'again." for a non-AppFailure error', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(
          initialError: Exception('boom'),
        ),
        task: _task(),
      );

      expect(find.text('Could not save task. Try again.'), findsOneWidget);
    });
  });

  group('TaskDetailSheet — success closes the sheet', () {
    testWidgets('add mode: the sheet is popped once addTaskProvider '
        'becomes AsyncData', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
      );
      expect(find.byType(TaskDetailSheet), findsOneWidget);

      await tester.enterText(_titleField, 'Buy milk');
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsNothing);
    });

    testWidgets('edit mode: the sheet is popped once updateTaskProvider '
        'becomes AsyncData', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(),
      );
      expect(find.byType(TaskDetailSheet), findsOneWidget);

      await tester.enterText(_titleField, 'Buy oat milk');
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsNothing);
    });
  });
}
