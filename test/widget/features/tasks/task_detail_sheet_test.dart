// Widget tests for TaskDetailSheet (S-04), rewritten for issue #56.
//
// What changed from the pre-#56 version of this file:
// - Add mode is gone (issue #55's InlineAddTaskRow replaced it), so `task`
//   is required and non-null and every add-mode group has been dropped.
// - There is no Save button and no pop-on-success: the title commits on
//   submit, the notes on blur, and the user dismisses the sheet themselves.
// - The title is tap-to-edit — a plain `Text` until tapped, a borderless
//   autofocused `TextField` after.
// - Delete delegates to the `onDelete` callback (TaskListScreen owns the
//   confirm dialog and undo SnackBar), so this file only asserts that the
//   sheet pops and invokes it.
// - Status and assignee behaviour now lives in status_pills_test.dart and
//   assignee_picker_test.dart; this file only overrides those providers so
//   the extracted widgets render without touching Firebase.
//
// The sheet is pumped via a real `showModalBottomSheet` from a tiny harness
// widget so the delete flow's `Navigator.pop()` can actually be observed.
//
// Every pumped MaterialApp sets `theme: AppTheme.light` — the sheet reads
// its colours via `AppColors.of(context)`, which null-asserts on a theme
// with no AppColors ThemeExtension registered.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/assignee_picker.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/status_pills.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/task_detail_sheet.dart';

const _spaceId = 'space-1';

const _currentUser = AppUser(
  id: 'uid-1',
  displayName: 'Ada',
  email: 'ada@example.com',
);
const _memberSelf = MemberAvatar(uid: 'uid-1', displayName: 'Ada');
const _memberBea = MemberAvatar(uid: 'uid-2', displayName: 'Bea');

Task _task({
  String id = 'task-1',
  String title = 'Buy milk',
  String? notes = 'Whole milk',
  TaskStatus status = TaskStatus.todo,
  String? assigneeUid,
}) {
  return Task(
    id: id,
    spaceId: _spaceId,
    title: title,
    notes: notes,
    status: status,
    assigneeUid: assigneeUid,
    createdBy: 'uid-1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

/// A controllable stand-in for [UpdateTaskController].
///
/// [initialError] makes the initial state `AsyncError`, as if a previous
/// save had failed.
class _FakeUpdateTaskController extends UpdateTaskController {
  _FakeUpdateTaskController({
    this.initialError,
    this.failWrites = false,
    this.manual = false,
  });

  final Object? initialError;

  /// Makes every `updateTask` land in `AsyncError`, the way a rejected
  /// Firestore write does — used to drive the sheet's rollback path.
  final bool failWrites;

  /// When set, each `updateTask` call parks on its own entry in [pending]
  /// until the test completes it — with `null` for success or a failure —
  /// so several writes can be in flight at once and resolved in any order.
  final bool manual;
  final List<Completer<AppFailure?>> pending = [];

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
    return null;
  }

  @override
  Future<AppFailure?> updateTask({
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
    if (manual) {
      final completer = Completer<AppFailure?>();
      pending.add(completer);
      final failure = await completer.future;
      state = failure == null
          ? const AsyncData(null)
          : AsyncError<void>(failure, StackTrace.current);
      return failure;
    }
    if (failWrites) {
      const failure = UnknownFailure();
      state = AsyncError<void>(failure, StackTrace.current);
      return failure;
    }
    state = const AsyncData(null);
    return null;
  }
}

/// Inert stand-ins for the two extracted child widgets' controllers — their
/// own behaviour is covered in status_pills_test.dart and
/// assignee_picker_test.dart; here they exist only so nothing reaches
/// Firestore while the sheet renders them.
class _FakeAssignTaskController extends AssignTaskController {
  @override
  FutureOr<void> build() {}

  @override
  Future<void> assignTask({
    required String spaceId,
    required String taskId,
    required String? assigneeUid,
  }) async {}
}

class _FakeUpdateStatusController extends UpdateStatusController {
  @override
  FutureOr<void> build() {}

  @override
  Future<void> updateStatus({
    required String spaceId,
    required String taskId,
    required TaskStatus status,
  }) async {}
}

/// Records whether the sheet's Delete action delegated back to its caller.
class _Harness {
  int onDeleteCallCount = 0;
}

/// Pumps a harness button that opens [TaskDetailSheet] via a real
/// `showModalBottomSheet`, with every Firestore-backed provider overridden.
Future<_Harness> _pumpSheet(
  WidgetTester tester, {
  required _FakeUpdateTaskController updateController,
  Task? task,
  List<MemberAvatar> members = const [_memberSelf, _memberBea],
  bool dark = false,
}) async {
  final harness = _Harness();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateTaskProvider.overrideWith(() => updateController),
        assignTaskProvider.overrideWith(_FakeAssignTaskController.new),
        updateStatusProvider.overrideWith(_FakeUpdateStatusController.new),
        authStateProvider.overrideWith((ref) => Stream.value(_currentUser)),
        spaceMembersProvider.overrideWith((ref, spaceId) async => members),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => TaskDetailSheet(
                    spaceId: _spaceId,
                    task: task ?? _task(),
                    onDelete: () => harness.onDeleteCallCount++,
                  ),
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
  // Bounded pumps rather than pumpAndSettle() so a test is never at the
  // mercy of an animation that doesn't settle; this is enough to finish the
  // bottom sheet's own entrance transition.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  // One more pump lets spaceMembersProvider (mocked to resolve
  // synchronously) deliver its data to AssigneePicker.
  await tester.pump();

  return harness;
}

AppColors _colors(WidgetTester tester) =>
    AppColors.of(tester.element(find.byType(TaskDetailSheet)));

/// Every [TextField] inside the sheet. The notes field is always present;
/// the title field only exists while the title is in edit mode, and when it
/// is, it comes first in the tree.
Finder get _sheetFields => find.descendant(
  of: find.byType(TaskDetailSheet),
  matching: find.byType(TextField),
);

Finder get _notesField => _sheetFields.last;

/// Taps the title's `Text` to swap it for the inline edit field.
Future<void> _tapTitle(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pump();
}

/// Blurs whatever currently has focus — how the notes field commits.
Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

void main() {
  group('TaskDetailSheet — chrome', () {
    testWidgets('renders the drag handle', (tester) async {
      await _pumpSheet(tester, updateController: _FakeUpdateTaskController());

      // The 36x4 pill above the title, matched by its own bottom margin.
      final handle = find.descendant(
        of: find.byType(TaskDetailSheet),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.margin == const EdgeInsets.only(bottom: 14),
        ),
      );
      expect(handle, findsOneWidget);
      // getSize would include the 14px bottom margin, so assert the
      // Container's own tight constraints instead.
      expect(
        tester.widget<Container>(handle).constraints,
        BoxConstraints.tight(const Size(36, 4)),
      );
    });

    testWidgets('renders the status pills and the assignee picker', (
      tester,
    ) async {
      await _pumpSheet(tester, updateController: _FakeUpdateTaskController());

      expect(find.byType(StatusPills), findsOneWidget);
      expect(find.byType(AssigneePicker), findsOneWidget);
    });

    testWidgets('renders in dark mode without throwing', (tester) async {
      await _pumpSheet(
        tester,
        updateController: _FakeUpdateTaskController(),
        dark: true,
      );

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('Delete task'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TaskDetailSheet — title, tap to edit', () {
    testWidgets('renders as plain Text initially, with no title TextField', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        updateController: _FakeUpdateTaskController(),
        task: _task(title: 'Buy milk'),
      );

      expect(find.text('Buy milk'), findsOneWidget);
      // Only the notes field — the title is not yet a field.
      expect(_sheetFields, findsOneWidget);
    });

    testWidgets('tapping it reveals an autofocused TextField holding the '
        'title', (tester) async {
      await _pumpSheet(
        tester,
        updateController: _FakeUpdateTaskController(),
        task: _task(title: 'Buy milk'),
      );

      await _tapTitle(tester, 'Buy milk');

      expect(_sheetFields, findsNWidgets(2));
      final titleField = tester.widget<TextField>(_sheetFields.first);
      expect(titleField.autofocus, isTrue);
      expect(titleField.controller!.text, 'Buy milk');
      // Opted out of the global filled inputDecorationTheme so it reads as
      // the title line becoming typable, not a grey box appearing.
      expect(titleField.decoration!.filled, isFalse);
    });

    testWidgets('submitting a valid new title saves once and reverts to '
        'Text', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(id: 'task-42', title: 'Buy milk', notes: 'Whole milk'),
      );

      await _tapTitle(tester, 'Buy milk');
      await tester.enterText(_sheetFields.first, 'Buy oat milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(updateController.updateTaskCallCount, 1);
      expect(updateController.lastSpaceId, _spaceId);
      expect(updateController.lastTaskId, 'task-42');
      expect(updateController.lastTitle, 'Buy oat milk');
      // updateTask writes title and notes together, so the untouched notes
      // ride along unchanged.
      expect(updateController.lastNotes, 'Whole milk');

      // Back to a plain Text — only the notes field remains.
      expect(_sheetFields, findsOneWidget);
      expect(find.text('Buy oat milk'), findsOneWidget);
    });

    testWidgets('a padded title is saved trimmed', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(title: 'Buy milk'),
      );

      await _tapTitle(tester, 'Buy milk');
      await tester.enterText(_sheetFields.first, '  Buy oat milk  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(updateController.lastTitle, 'Buy oat milk');
    });
  });

  group('TaskDetailSheet — title validation', () {
    testWidgets('an empty title shows "Title is required", stays in edit '
        'mode, and does not save', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(title: 'Buy milk'),
      );

      await _tapTitle(tester, 'Buy milk');
      await tester.enterText(_sheetFields.first, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Title is required'), findsOneWidget);
      expect(updateController.updateTaskCallCount, 0);
      // Still a TextField — it did not revert to a text display of
      // something that was never saved.
      expect(_sheetFields, findsNWidgets(2));
    });

    testWidgets('a whitespace-only title is treated as empty', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(title: 'Buy milk'),
      );

      await _tapTitle(tester, 'Buy milk');
      await tester.enterText(_sheetFields.first, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Title is required'), findsOneWidget);
      expect(updateController.updateTaskCallCount, 0);
      expect(_sheetFields, findsNWidgets(2));
    });

    testWidgets('a title over taskTitleMaxLength shows the length error and '
        'does not save', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(title: 'Buy milk'),
      );

      await _tapTitle(tester, 'Buy milk');
      // Bypass the field's own maxLength input formatter (which would
      // silently clamp text entered via enterText) by mutating the
      // controller directly, so the over-length branch can be reached.
      tester.widget<TextField>(_sheetFields.first).controller!.text =
          'a' * (AppConstants.taskTitleMaxLength + 1);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        find.text(
          'Title must be ${AppConstants.taskTitleMaxLength} characters or '
          'fewer',
        ),
        findsOneWidget,
      );
      expect(updateController.updateTaskCallCount, 0);
    });
  });

  group('TaskDetailSheet — notes', () {
    testWidgets('is pre-filled from the task', (tester) async {
      await _pumpSheet(
        tester,
        updateController: _FakeUpdateTaskController(),
        task: _task(notes: 'Whole milk'),
      );

      expect(
        tester.widget<TextField>(_notesField).controller!.text,
        'Whole milk',
      );
    });

    testWidgets('blurring after a change saves the new notes alongside the '
        'unchanged title', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(id: 'task-42', title: 'Buy milk', notes: 'Whole milk'),
      );

      await tester.tap(_notesField);
      await tester.pump();
      await tester.enterText(_notesField, '  From the co-op  ');
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 1);
      expect(updateController.lastTaskId, 'task-42');
      expect(updateController.lastTitle, 'Buy milk');
      expect(updateController.lastNotes, 'From the co-op');
    });

    testWidgets('clearing the notes saves null', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(notes: 'Whole milk'),
      );

      await tester.tap(_notesField);
      await tester.pump();
      await tester.enterText(_notesField, '   ');
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 1);
      expect(updateController.lastNotes, isNull);
    });
  });

  group('TaskDetailSheet — dirty check', () {
    // The sheet must not write when nothing actually changed: notes commit
    // on blur, so without the dirty check merely focusing the notes field
    // and tapping away bumped the task's `updatedAt`, which reorders the
    // space on Home (it sorts by most recently updated).
    testWidgets('focusing the notes field and blurring without typing does '
        'NOT save', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(title: 'Buy milk', notes: 'Whole milk'),
      );

      await tester.tap(_notesField);
      await tester.pump();
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 0);
    });

    testWidgets('re-submitting the same title does NOT save', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(title: 'Buy milk'),
      );

      await _tapTitle(tester, 'Buy milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(updateController.updateTaskCallCount, 0);
      // Still reverts to the text display — an unchanged submit is a
      // successful no-op, not a validation failure.
      expect(_sheetFields, findsOneWidget);
    });

    testWidgets('a task with null notes blurred untouched does NOT save — '
        'empty text and null notes are the same value', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(notes: null),
      );

      await tester.tap(_notesField);
      await tester.pump();
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 0);
    });

    testWidgets('a changed value saves exactly once, and blurring again '
        'without a further change does not save a second time', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(notes: 'Whole milk'),
      );

      await tester.tap(_notesField);
      await tester.pump();
      await tester.enterText(_notesField, 'Oat milk');
      await _blur(tester);
      expect(updateController.updateTaskCallCount, 1);
      expect(updateController.lastNotes, 'Oat milk');

      await tester.tap(_notesField);
      await tester.pump();
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 1);
    });
  });

  group('TaskDetailSheet — delete', () {
    testWidgets('tapping "Delete task" pops the sheet and invokes onDelete', (
      tester,
    ) async {
      final harness = await _pumpSheet(
        tester,
        updateController: _FakeUpdateTaskController(),
      );
      expect(find.byType(TaskDetailSheet), findsOneWidget);

      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();

      expect(harness.onDeleteCallCount, 1);
      expect(find.byType(TaskDetailSheet), findsNothing);
    });

    testWidgets('does not delete anything itself — no confirm dialog or '
        'SnackBar is built here', (tester) async {
      await _pumpSheet(tester, updateController: _FakeUpdateTaskController());

      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('TaskDetailSheet — save error state', () {
    testWidgets("shows an AppFailure's own message inline in 13px danger", (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        updateController: _FakeUpdateTaskController(
          initialError: const NetworkFailure(),
        ),
      );

      final text = find.text('No internet connection');
      expect(text, findsOneWidget);
      final style = tester.widget<Text>(text).style!;
      expect(style.color, _colors(tester).danger);
      expect(style.fontSize, 13);
    });

    testWidgets('falls back to "Could not save task. Try again." for a '
        'non-AppFailure error', (tester) async {
      await _pumpSheet(
        tester,
        updateController: _FakeUpdateTaskController(
          initialError: Exception('boom'),
        ),
      );

      expect(find.text('Could not save task. Try again.'), findsOneWidget);
    });

    testWidgets('shows no error text in the pristine state', (tester) async {
      await _pumpSheet(tester, updateController: _FakeUpdateTaskController());

      expect(find.text('Could not save task. Try again.'), findsNothing);
    });
  });

  group('TaskDetailSheet — dirty check, awkward stored values', () {
    testWidgets('a task whose stored notes are an empty string is not dirty '
        'on an untouched blur', (tester) async {
      // '' and null both normalise to "no notes". Seeding the comparison
      // with the raw '' made them differ, so simply looking at the field
      // wrote and reordered the space on Home.
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(notes: ''),
      );

      await tester.tap(_notesField);
      await tester.pump();
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 0);
    });

    testWidgets('a task whose stored title has stray whitespace is not dirty '
        'on an untouched blur', (tester) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(title: '  Buy milk  ', notes: null),
      );

      await tester.tap(_notesField);
      await tester.pump();
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 0);
    });
  });

  group('TaskDetailSheet — a failed write can be retried', () {
    testWidgets('re-blurring the same text after a failure sends it again, '
        'rather than being skipped as unchanged', (tester) async {
      final updateController = _FakeUpdateTaskController(failWrites: true);
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(notes: 'Whole milk'),
      );

      await tester.tap(_notesField);
      await tester.pump();
      await tester.enterText(_notesField, 'From the co-op');
      await _blur(tester);
      expect(updateController.updateTaskCallCount, 1);

      // Nothing further typed. Without rolling the saved values back on
      // failure, this second blur looks like a no-op and the edit is lost.
      await tester.tap(_notesField);
      await tester.pump();
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 2);
      expect(updateController.lastNotes, 'From the co-op');
    });

    testWidgets('a successful write is still not re-sent on a later blur', (
      tester,
    ) async {
      final updateController = _FakeUpdateTaskController();
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(notes: 'Whole milk'),
      );

      await tester.tap(_notesField);
      await tester.pump();
      await tester.enterText(_notesField, 'From the co-op');
      await _blur(tester);
      await tester.tap(_notesField);
      await tester.pump();
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 1);
    });
  });

  group(
    'TaskDetailSheet — dismissed while the notes field still has focus',
    () {
      testWidgets('keeps the typed notes instead of dropping them', (
        tester,
      ) async {
        // Every dismissal pops the route, and the notes field loses focus as
        // the route is torn down — while the blur listener is still attached,
        // so the commit fires before dispose() removes it. That ordering is
        // incidental Flutter behaviour rather than a contract, which is why
        // it's pinned here: if it ever changes, typed notes start vanishing
        // on dismiss and this fails.
        final updateController = _FakeUpdateTaskController();
        await _pumpSheet(
          tester,
          updateController: updateController,
          task: _task(notes: 'Whole milk'),
        );

        await tester.tap(_notesField);
        await tester.pump();
        await tester.enterText(_notesField, 'Typed but never blurred');
        expect(updateController.updateTaskCallCount, 0);

        // A real downward fling, the production drag-dismiss gesture —
        // the dismissal least likely to unfocus the field on its way out.
        await tester.fling(
          find.byType(TaskDetailSheet),
          const Offset(0, 600),
          2000,
        );
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailSheet), findsNothing);
        expect(updateController.updateTaskCallCount, 1);
        expect(updateController.lastNotes, 'Typed but never blurred');
      });

      testWidgets('dismissing without typing anything writes nothing', (
        tester,
      ) async {
        final updateController = _FakeUpdateTaskController();
        await _pumpSheet(
          tester,
          updateController: updateController,
          task: _task(notes: 'Whole milk'),
        );

        await tester.fling(
          find.byType(TaskDetailSheet),
          const Offset(0, 600),
          2000,
        );
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailSheet), findsNothing);
        expect(updateController.updateTaskCallCount, 0);
      });
    },
  );

  group('TaskDetailSheet — overlapping writes', () {
    Future<void> typeNotesAndBlur(WidgetTester tester, String text) async {
      await tester.tap(_notesField);
      await tester.pump();
      await tester.enterText(_notesField, text);
      await _blur(tester);
    }

    testWidgets('two writes that both fail, the older resolving first, still '
        'let the older value be sent again', (tester) async {
      // The case that broke a per-write rollback: the older write's failure
      // saw the newer values and did nothing, then the newer one restored
      // the older value — leaving the sheet believing Firestore held text it
      // never received, so retyping it was skipped as unchanged.
      final updateController = _FakeUpdateTaskController(manual: true);
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(notes: 'Whole milk'),
      );

      await typeNotesAndBlur(tester, 'From the co-op');
      await typeNotesAndBlur(tester, 'From the market');
      expect(updateController.updateTaskCallCount, 2);

      updateController.pending[0].complete(const UnknownFailure());
      await tester.pump();
      updateController.pending[1].complete(const UnknownFailure());
      await tester.pump();

      await typeNotesAndBlur(tester, 'From the co-op');

      expect(updateController.updateTaskCallCount, 3);
      expect(updateController.lastNotes, 'From the co-op');
    });

    testWidgets('a late failure from an older write makes an unchanged '
        're-blur send again', (tester) async {
      // Once any write has failed, the sheet can no longer be sure what
      // Firestore holds, so it errs toward sending — one spare write rather
      // than a silently lost edit.
      final updateController = _FakeUpdateTaskController(manual: true);
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(notes: 'Whole milk'),
      );

      await typeNotesAndBlur(tester, 'From the co-op');
      await typeNotesAndBlur(tester, 'From the market');

      updateController.pending[1].complete(null);
      await tester.pump();
      updateController.pending[0].complete(const UnknownFailure());
      await tester.pump();

      // Nothing new typed — the field still reads the newer value.
      await tester.tap(_notesField);
      await tester.pump();
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 3);
      expect(updateController.lastNotes, 'From the market');
      updateController.pending[2].complete(null);
      await tester.pump();
    });

    testWidgets('with no failure, overlapping successful writes do not cause '
        'a spare write', (tester) async {
      final updateController = _FakeUpdateTaskController(manual: true);
      await _pumpSheet(
        tester,
        updateController: updateController,
        task: _task(notes: 'Whole milk'),
      );

      await typeNotesAndBlur(tester, 'From the co-op');
      await typeNotesAndBlur(tester, 'From the market');
      updateController.pending[1].complete(null);
      updateController.pending[0].complete(null);
      await tester.pump();

      await tester.tap(_notesField);
      await tester.pump();
      await _blur(tester);

      expect(updateController.updateTaskCallCount, 2);
    });
  });
}
