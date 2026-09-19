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
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/task_detail_sheet.dart';

const _spaceId = 'space-1';

// Issue #9 — "Assign to" section fixtures. The signed-in user is always
// included in the member list passed to spaceMembersProvider (matching
// production: a space's own members include the current user), placed
// mid-list on purpose so tests can verify _AssignToSection reorders them to
// the front, not merely preserves an already-first position.
const _currentUser = AppUser(id: 'uid-1', displayName: 'Ada', email: 'ada@example.com');
const _memberSelf = MemberAvatar(uid: 'uid-1', displayName: 'Ada');
const _memberBea = MemberAvatar(uid: 'uid-2', displayName: 'Bea');
const _memberCleo = MemberAvatar(uid: 'uid-3', displayName: 'Cleo');

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
  Future<AppFailure?> addTask({
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
    return null;
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

/// A controllable stand-in for [AssignTaskController]. Same knobs as
/// [_FakeUpdateTaskController], plus assigneeUid recording — `null` is a
/// valid recorded value (unassign), so [assignTaskCallCount] is what tests
/// should check to know whether a call happened at all.
class _FakeAssignTaskController extends AssignTaskController {
  _FakeAssignTaskController({
    this.initialError,
    this.pending = false,
    this.failOnAssign = false,
  });

  final Object? initialError;
  final bool pending;

  /// When true, every [assignTask] call resolves to [AsyncError] instead
  /// of [AsyncData] — for testing that a failed write rolls the sheet's
  /// optimistic selection back rather than leaving it claiming an
  /// assignment that was never actually saved. Mutable so a test can
  /// flip it mid-flow (e.g. first assignment succeeds, then fails).
  bool failOnAssign;

  int assignTaskCallCount = 0;
  String? lastSpaceId;
  String? lastTaskId;
  String? lastAssigneeUid;

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
  Future<void> assignTask({
    required String spaceId,
    required String taskId,
    required String? assigneeUid,
  }) async {
    assignTaskCallCount++;
    lastSpaceId = spaceId;
    lastTaskId = taskId;
    lastAssigneeUid = assigneeUid;
    state = const AsyncLoading();
    if (failOnAssign) {
      state = AsyncError(Exception('assign failed'), StackTrace.current);
    } else {
      state = const AsyncData(null);
    }
  }
}

/// A controllable stand-in for [UpdateStatusController]. Same knobs as
/// [_FakeAssignTaskController] — [initialError]/[pending] for the sheet's
/// own loading/error rendering, plus [failOnUpdate] (mutable, mirroring
/// [_FakeAssignTaskController.failOnAssign]) for testing that a failed
/// status write rolls `_StatusSection`'s optimistic selection back rather
/// than leaving it claiming a status that was never actually saved.
class _FakeUpdateStatusController extends UpdateStatusController {
  _FakeUpdateStatusController({
    this.initialError,
    this.pending = false,
    this.failOnUpdate = false,
  });

  final Object? initialError;
  final bool pending;

  /// When true, every [updateStatus] call resolves to [AsyncError] instead
  /// of [AsyncData]. Mutable so a test can flip it mid-flow (e.g. first
  /// change succeeds, then fails).
  bool failOnUpdate;

  int updateStatusCallCount = 0;
  String? lastSpaceId;
  String? lastTaskId;
  TaskStatus? lastStatus;

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
  Future<void> updateStatus({
    required String spaceId,
    required String taskId,
    required TaskStatus status,
  }) async {
    updateStatusCallCount++;
    lastSpaceId = spaceId;
    lastTaskId = taskId;
    lastStatus = status;
    state = const AsyncLoading();
    if (failOnUpdate) {
      state = AsyncError(Exception('update status failed'), StackTrace.current);
    } else {
      state = const AsyncData(null);
    }
  }
}

/// Pumps a tiny harness (a button that opens [TaskDetailSheet] via a real
/// `showModalBottomSheet`) with [addTaskProvider], [updateTaskProvider], and
/// [assignTaskProvider] overridden to fakes, plus [authStateProvider] and
/// [spaceMembersProvider(spaceId)] overridden so the "Assign to" section
/// (edit mode only) never touches real Firebase — then taps the button so
/// the sheet is showing.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required _FakeAddTaskController addController,
  required _FakeUpdateTaskController updateController,
  _FakeAssignTaskController? assignController,
  _FakeUpdateStatusController? updateStatusController,
  Task? task,
  AppUser currentUser = _currentUser,
  List<MemberAvatar> members = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addTaskProvider.overrideWith(() => addController),
        updateTaskProvider.overrideWith(() => updateController),
        assignTaskProvider.overrideWith(
          () => assignController ?? _FakeAssignTaskController(),
        ),
        updateStatusProvider.overrideWith(
          () => updateStatusController ?? _FakeUpdateStatusController(),
        ),
        authStateProvider.overrideWith((ref) => Stream.value(currentUser)),
        spaceMembersProvider.overrideWith((ref, spaceId) async => members),
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
  // One more pump lets spaceMembersProvider's FutureProvider (mocked to
  // resolve synchronously via `async => members`) deliver its data, so the
  // "Assign to" section's `membersState.when(data: ...)` branch is what
  // renders by the time a test starts making assertions.
  await tester.pump();
}

Finder _avatarInkWellFor(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

/// The `BoxDecoration` of the avatar's own selection-ring `Container` —
/// see `_AssigneeAvatar` in task_detail_sheet.dart. `border` is non-null
/// exactly when that avatar is the currently-selected assignee.
///
/// Matched by its `padding: EdgeInsets.all(2)` (set in `_AssigneeAvatar`)
/// rather than just `find.byType(Container)` — `CircleAvatar` itself
/// builds an internal `AnimatedContainer`, whose own `State` builds a
/// `Container` too, so a bare type match finds two candidates per avatar.
BoxDecoration _avatarDecorationFor(WidgetTester tester, String label) {
  final sizedBox = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 64),
  );
  final container = find.descendant(
    of: sizedBox,
    matching: find.byWidgetPredicate(
      (widget) => widget is Container && widget.padding == const EdgeInsets.all(2),
    ),
  );
  return tester.widget<Container>(container).decoration! as BoxDecoration;
}

Finder get _titleField => find.byType(TextField).first;
Finder get _notesField => find.byType(TextField).at(1);

/// The [SegmentedButton] driving [_StatusSection] (issue #10).
Finder get _statusSegmentedButton =>
    find.byType(SegmentedButton<TaskStatus>);

TaskStatus _selectedStatus(WidgetTester tester) =>
    tester.widget<SegmentedButton<TaskStatus>>(_statusSegmentedButton).selected.single;

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
      // Issue #10's Status section pushes Save below the fold in edit
      // mode's now-taller sheet — scroll it into view before tapping.
      await tester.ensureVisible(find.byType(AppButton));
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
      // Issue #10's Status section pushes Save below the fold in edit
      // mode's now-taller sheet — scroll it into view before tapping.
      await tester.ensureVisible(find.byType(AppButton));
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsNothing);
    });
  });

  group('TaskDetailSheet — Assign to section, visibility and placement', () {
    testWidgets('does not render in add mode', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        members: const [_memberSelf, _memberBea],
      );

      expect(find.text('Assign to'), findsNothing);
    });

    testWidgets('renders in edit mode', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(),
        members: const [_memberSelf, _memberBea],
      );

      expect(find.text('Assign to'), findsOneWidget);
    });

    testWidgets('appears between the Title field and the Notes field',
        (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(),
        members: const [_memberSelf, _memberBea],
      );

      final titleDy = tester.getTopLeft(_titleField).dy;
      final assignToDy = tester.getTopLeft(find.text('Assign to')).dy;
      final notesDy = tester.getTopLeft(_notesField).dy;

      expect(titleDy, lessThan(assignToDy));
      expect(assignToDy, lessThan(notesDy));
    });
  });

  group('TaskDetailSheet — Assign to section, avatar row', () {
    testWidgets("the signed-in user's own avatar is first and shows \"Me\"",
        (tester) async {
      // _memberSelf placed mid-list on purpose — the section must reorder
      // it to the front, not merely happen to already be first.
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(),
        members: const [_memberBea, _memberSelf, _memberCleo],
      );

      expect(find.text('Me'), findsOneWidget);
      // The current user's own display name is never shown as a label —
      // "Me" replaces it.
      expect(find.text('Ada'), findsNothing);

      final meDx = tester.getTopLeft(find.text('Me')).dx;
      final beaDx = tester.getTopLeft(find.text('Bea')).dx;
      final cleoDx = tester.getTopLeft(find.text('Cleo')).dx;

      expect(meDx, lessThan(beaDx));
      expect(meDx, lessThan(cleoDx));
    });

    testWidgets("the currently-assigned member's avatar shows the "
        'selection ring, others do not', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(assigneeUid: _memberBea.uid),
        members: const [_memberSelf, _memberBea, _memberCleo],
      );

      expect(_avatarDecorationFor(tester, 'Bea').border, isNotNull);
      expect(_avatarDecorationFor(tester, 'Me').border, isNull);
      expect(_avatarDecorationFor(tester, 'Cleo').border, isNull);
    });

    testWidgets('no avatar shows the selection ring when unassigned',
        (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(),
        members: const [_memberSelf, _memberBea],
      );

      expect(_avatarDecorationFor(tester, 'Me').border, isNull);
      expect(_avatarDecorationFor(tester, 'Bea').border, isNull);
    });

    testWidgets('shows "Unassigned" text when nobody is assigned',
        (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(),
        members: const [_memberSelf, _memberBea],
      );

      expect(find.text('Unassigned'), findsOneWidget);
    });

    testWidgets('does not show "Unassigned" text when someone is assigned',
        (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(assigneeUid: _memberBea.uid),
        members: const [_memberSelf, _memberBea],
      );

      expect(find.text('Unassigned'), findsNothing);
    });
  });

  group('TaskDetailSheet — Assign to section, tapping an avatar', () {
    testWidgets('tapping an avatar calls assignTaskProvider with the '
        'correct spaceId/taskId/assigneeUid', (tester) async {
      final assignController = _FakeAssignTaskController();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        assignController: assignController,
        task: _task(id: 'task-42'),
        members: const [_memberSelf, _memberBea],
      );

      await tester.tap(_avatarInkWellFor('Bea'));
      await tester.pump();

      expect(assignController.assignTaskCallCount, 1);
      expect(assignController.lastSpaceId, _spaceId);
      expect(assignController.lastTaskId, 'task-42');
      expect(assignController.lastAssigneeUid, _memberBea.uid);
    });

    testWidgets('tapping "Me" calls assignTaskProvider with the '
        "signed-in user's own uid", (tester) async {
      final assignController = _FakeAssignTaskController();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        assignController: assignController,
        task: _task(id: 'task-42'),
        members: const [_memberSelf, _memberBea],
      );

      await tester.tap(_avatarInkWellFor('Me'));
      await tester.pump();

      expect(assignController.assignTaskCallCount, 1);
      expect(assignController.lastAssigneeUid, _memberSelf.uid);
    });

    testWidgets('tapping the currently-assigned avatar again calls assign '
        'with a null assigneeUid (unassign)', (tester) async {
      final assignController = _FakeAssignTaskController();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        assignController: assignController,
        task: _task(id: 'task-42', assigneeUid: _memberBea.uid),
        members: const [_memberSelf, _memberBea],
      );

      await tester.tap(_avatarInkWellFor('Bea'));
      await tester.pump();

      expect(assignController.assignTaskCallCount, 1);
      expect(assignController.lastSpaceId, _spaceId);
      expect(assignController.lastTaskId, 'task-42');
      expect(assignController.lastAssigneeUid, isNull);
    });
  });

  group('TaskDetailSheet — Assign to section, error state', () {
    testWidgets('shows the inline error text when assignTaskProvider has an '
        'error', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        assignController: _FakeAssignTaskController(
          initialError: Exception('boom'),
        ),
        task: _task(),
        members: const [_memberSelf, _memberBea],
      );

      expect(
        find.text('Could not update assignee. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shows no inline error text in the pristine state',
        (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(),
        members: const [_memberSelf, _memberBea],
      );

      expect(
        find.text('Could not update assignee. Try again.'),
        findsNothing,
      );
    });

    testWidgets('shows no inline error text while an assign write is still '
        'in flight (AsyncLoading)', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        assignController: _FakeAssignTaskController(pending: true),
        task: _task(),
        members: const [_memberSelf, _memberBea],
      );

      expect(
        find.text('Could not update assignee. Try again.'),
        findsNothing,
      );
    });

    testWidgets('rolls the selection back to the previous assignee when '
        'the write fails, instead of leaving the ring on the tapped '
        'avatar', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        assignController: _FakeAssignTaskController(failOnAssign: true),
        task: _task(assigneeUid: _memberBea.uid),
        members: const [_memberSelf, _memberBea, _memberCleo],
      );

      await tester.tap(_avatarInkWellFor('Cleo'));
      // The fake resolves assignTask without any real async gap, so the
      // optimistic move and its revert both land within the same pump —
      // there's no reliably-observable moment in between. What matters is
      // the settled outcome: the ring ends up back on Bea (who was still
      // actually assigned in Firestore), not left on Cleo, whose write
      // never went through.
      await tester.pump();

      expect(_avatarDecorationFor(tester, 'Bea').border, isNotNull);
      expect(_avatarDecorationFor(tester, 'Cleo').border, isNull);
      expect(
        find.text('Could not update assignee. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a second, successful assignment after a failed one rolls '
        'back to the successful one on a later failure — not the sheet\'s '
        'original opening value', (tester) async {
      final assignController = _FakeAssignTaskController();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        assignController: assignController,
        task: _task(), // opens unassigned
        members: const [_memberSelf, _memberBea, _memberCleo],
      );

      // First tap succeeds — Bea becomes the confirmed assignee.
      await tester.tap(_avatarInkWellFor('Bea'));
      await tester.pump();
      await tester.pump();
      expect(_avatarDecorationFor(tester, 'Bea').border, isNotNull);

      // Second tap fails — should roll back to Bea (the last confirmed
      // value), not all the way back to unassigned.
      assignController.failOnAssign = true;
      await tester.tap(_avatarInkWellFor('Cleo'));
      await tester.pump();
      await tester.pump();

      expect(_avatarDecorationFor(tester, 'Bea').border, isNotNull);
      expect(_avatarDecorationFor(tester, 'Cleo').border, isNull);
      expect(find.text('Unassigned'), findsNothing);
    });

    testWidgets('rolls the selection back and shows the inline error text '
        'when the write is offline-blocked — same rollback mechanism as a '
        'genuine repository failure, just a different trigger (issue #11)',
        (tester) async {
      // _FakeAssignTaskController.failOnAssign resolves to AsyncError the
      // same way the real _blockIfOffline guard does (see
      // tasks_provider.dart) — _AssignToSectionState only cares that
      // `next.hasError` is true, not why, so this fake is a faithful stand-in
      // for "the write was offline-blocked" without needing the real
      // controller/isOnlineProvider machinery (that's covered separately in
      // tasks_provider_offline_test.dart).
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        assignController: _FakeAssignTaskController(failOnAssign: true),
        task: _task(assigneeUid: _memberBea.uid),
        members: const [_memberSelf, _memberBea, _memberCleo],
      );

      await tester.tap(_avatarInkWellFor('Cleo'));
      await tester.pump();

      expect(_avatarDecorationFor(tester, 'Bea').border, isNotNull);
      expect(_avatarDecorationFor(tester, 'Cleo').border, isNull);
      expect(
        find.text('Could not update assignee. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('TaskDetailSheet — Status section, rendering', () {
    testWidgets('does not render in add mode', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
      );

      expect(find.text('Status'), findsNothing);
      expect(_statusSegmentedButton, findsNothing);
    });

    testWidgets('renders in edit mode with the segment matching the task\'s '
        'current status pre-selected', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(status: TaskStatus.inProgress),
      );

      expect(find.text('Status'), findsOneWidget);
      expect(_statusSegmentedButton, findsOneWidget);
      expect(_selectedStatus(tester), TaskStatus.inProgress);
    });

    testWidgets('pre-selects Todo when the task is todo', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(status: TaskStatus.todo),
      );

      expect(_selectedStatus(tester), TaskStatus.todo);
    });

    testWidgets('pre-selects Done when the task is done', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(status: TaskStatus.done),
      );

      expect(_selectedStatus(tester), TaskStatus.done);
    });
  });

  group('TaskDetailSheet — Status section, selecting a segment', () {
    testWidgets('selecting a different segment calls updateStatusProvider '
        'with the correct spaceId/taskId/status', (tester) async {
      final updateStatusController = _FakeUpdateStatusController();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        updateStatusController: updateStatusController,
        task: _task(id: 'task-42', status: TaskStatus.todo),
      );

      await tester.tap(find.text('In Progress'));
      await tester.pump();

      expect(updateStatusController.updateStatusCallCount, 1);
      expect(updateStatusController.lastSpaceId, _spaceId);
      expect(updateStatusController.lastTaskId, 'task-42');
      expect(updateStatusController.lastStatus, TaskStatus.inProgress);
    });

    testWidgets('selecting the segment that is already selected does not '
        'call updateStatusProvider again — mirrors '
        '_StatusSectionState._onStatusSelected\'s early return when '
        'unchanged', (tester) async {
      final updateStatusController = _FakeUpdateStatusController();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        updateStatusController: updateStatusController,
        task: _task(status: TaskStatus.todo),
      );

      await tester.tap(find.text('Todo'));
      await tester.pump();

      expect(updateStatusController.updateStatusCallCount, 0);
    });
  });

  group('TaskDetailSheet — Status section, error state', () {
    testWidgets('shows the inline error text when updateStatusProvider has '
        'an error', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        updateStatusController: _FakeUpdateStatusController(
          initialError: Exception('boom'),
        ),
        task: _task(),
      );

      expect(
        find.text('Could not update status. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shows no inline error text in the pristine state',
        (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        task: _task(),
      );

      expect(
        find.text('Could not update status. Try again.'),
        findsNothing,
      );
    });

    testWidgets('shows no inline error text while a status write is still '
        'in flight (AsyncLoading)', (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        updateStatusController: _FakeUpdateStatusController(pending: true),
        task: _task(),
      );

      expect(
        find.text('Could not update status. Try again.'),
        findsNothing,
      );
    });

    testWidgets('rolls the segmented control back to the previous status '
        'when the write fails, instead of leaving it on the tapped segment',
        (tester) async {
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        updateStatusController: _FakeUpdateStatusController(
          failOnUpdate: true,
        ),
        task: _task(status: TaskStatus.todo),
      );

      await tester.tap(find.text('Done'));
      // The fake resolves updateStatus without any real async gap, so the
      // optimistic move and its revert both land within the same pump —
      // there's no reliably-observable moment in between. What matters is
      // the settled outcome: the selection ends back on Todo (what was
      // still actually saved in Firestore), not left on Done, whose write
      // never went through.
      await tester.pump();

      expect(_selectedStatus(tester), TaskStatus.todo);
      expect(
        find.text('Could not update status. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a second, successful status change after a failed one '
        'rolls back to the successful one on a later failure — not the '
        'sheet\'s original opening value', (tester) async {
      final updateStatusController = _FakeUpdateStatusController();
      await _pumpSheet(
        tester,
        addController: _FakeAddTaskController(),
        updateController: _FakeUpdateTaskController(),
        updateStatusController: updateStatusController,
        task: _task(status: TaskStatus.todo),
      );

      // First tap succeeds — inProgress becomes the confirmed status.
      await tester.tap(find.text('In Progress'));
      await tester.pump();
      await tester.pump();
      expect(_selectedStatus(tester), TaskStatus.inProgress);

      // Second tap fails — should roll back to inProgress (the last
      // confirmed value), not all the way back to the original todo.
      updateStatusController.failOnUpdate = true;
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump();

      expect(_selectedStatus(tester), TaskStatus.inProgress);
    });
  });
}
