// Widget tests for TaskListScreen (S-03), updated for issue #55's redesign.
// Controls taskListProvider(spaceId) — a StreamProvider.autoDispose.family —
// via the standard Riverpod family override syntax
// (`overrideWith((ref, spaceId) => stream)`), mirroring home_screen_test.dart's
// single-pump-after-pumpWidget pattern for stream-backed providers. Also
// overrides deleteTaskProvider, addTaskProvider, updateTaskProvider and
// updateStatusProvider with fake AutoDisposeAsyncNotifier subclasses
// (mirroring settings_screen_test.dart's _FakeSignOutNotifier /
// create_space_screen_test.dart's _FakeCreateSpaceNotifier pattern) so
// opening TaskDetailSheet, the inline add row and the Remove flow never reach
// real Firestore, plus spaceProvider/spaceMembersProvider, which issue #55's
// custom header reads for its title and member-names subtitle. Never touches
// real Firebase or Firestore.
//
// Every pumped MaterialApp sets `theme: AppTheme.light` — the screen and its
// rows read colours via `AppColors.of(context)`, which null-asserts on a
// theme with no AppColors ThemeExtension registered (see
// home_screen_test.dart for the same pattern).
//
// Per-widget behaviour of the two extracted widgets lives in
// task_row_test.dart and inline_add_task_row_test.dart; this file covers how
// the screen composes them.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/task_detail_sheet.dart';
import 'package:shared_tasks/features/tasks/presentation/task_list_screen.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/inline_add_task_row.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/task_row.dart';

const _spaceId = 'space-1';

// Issue #9 — assignee indicator fixtures.
const _memberBea = MemberAvatar(uid: 'uid-2', displayName: 'Bea');
const _memberAda = MemberAvatar(uid: 'uid-1', displayName: 'Ada');

final _space = Space(
  id: _spaceId,
  name: 'Kitchen',
  ownerUid: 'uid-1',
  memberUids: const ['uid-1', 'uid-2'],
  inviteToken: 'token',
  inviteExpiresAt: DateTime(2027, 1, 1),
  createdAt: DateTime(2026, 1, 1),
);

Task _task(
  String id, {
  String title = 'Task',
  String? notes,
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
  Future<void> deleteTask({
    required String spaceId,
    required String taskId,
  }) async {
    deleteTaskCallCount++;
    lastSpaceId = spaceId;
    lastTaskId = taskId;
  }
}

/// A controllable stand-in for [AddTaskController]. Records every call —
/// [InlineAddTaskRow] drives this, and menu actions must never trigger it.
class _FakeAddTaskController extends AddTaskController {
  int addTaskCallCount = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<AppFailure?> addTask({
    required String spaceId,
    required String title,
    String? notes,
  }) async {
    addTaskCallCount++;
    return null;
  }
}

/// A controllable stand-in for [UpdateTaskController]. Records every call —
/// used to verify menu actions never trigger a real update.
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

/// A controllable stand-in for [UpdateStatusController]. Records every
/// call — used to verify the row's status icon and the "Mark done" menu
/// item each trigger a real status write (issue #10).
class _FakeUpdateStatusController extends UpdateStatusController {
  int updateStatusCallCount = 0;
  String? lastSpaceId;
  String? lastTaskId;
  TaskStatus? lastStatus;

  @override
  FutureOr<void> build() {}

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
  }
}

class _Fakes {
  _Fakes()
    : deleteTaskController = _FakeDeleteTaskController(),
      addTaskController = _FakeAddTaskController(),
      updateTaskController = _FakeUpdateTaskController(),
      updateStatusController = _FakeUpdateStatusController();

  final _FakeDeleteTaskController deleteTaskController;
  final _FakeAddTaskController addTaskController;
  final _FakeUpdateTaskController updateTaskController;
  final _FakeUpdateStatusController updateStatusController;
}

/// Every provider the screen (and the widgets it composes) would otherwise
/// resolve through real Firestore.
List<Override> _overrides(
  _Fakes fakes, {
  required Stream<List<Task>> stream,
  required List<MemberAvatar> members,
  Stream<Space?>? spaceStream,
}) {
  return [
    taskListProvider.overrideWith((ref, spaceId) => stream),
    deleteTaskProvider.overrideWith(() => fakes.deleteTaskController),
    addTaskProvider.overrideWith(() => fakes.addTaskController),
    updateTaskProvider.overrideWith(() => fakes.updateTaskController),
    updateStatusProvider.overrideWith(() => fakes.updateStatusController),
    spaceProvider.overrideWith(
      (ref, spaceId) => spaceStream ?? Stream<Space?>.value(_space),
    ),
    spaceMembersProvider.overrideWith((ref, spaceId) async => members),
  ];
}

/// Pumps [TaskListScreen] with every Firestore-backed provider overridden.
///
/// [openTaskId] defaults to `null`, matching every navigation into this
/// screen before issue #12 — pass it to exercise the notification
/// auto-open behavior. [spaceStream] defaults to a space named "Kitchen";
/// pass an empty stream to exercise the header's still-loading fallback.
Future<_Fakes> _pumpScreen(
  WidgetTester tester, {
  required Stream<List<Task>> stream,
  List<MemberAvatar> members = const [],
  String? openTaskId,
  Stream<Space?>? spaceStream,
  bool dark = false,
}) async {
  final fakes = _Fakes();

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(
        fakes,
        stream: stream,
        members: members,
        spaceStream: spaceStream,
      ),
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: TaskListScreen(spaceId: _spaceId, openTaskId: openTaskId),
      ),
    ),
  );
  await tester.pump();
  // Lets spaceProvider/spaceMembersProvider (both mocked to resolve
  // synchronously) deliver their data before a test starts asserting on the
  // header or the assignee indicator.
  await tester.pump();

  return fakes;
}

/// A minimal real GoRouter harness (home → task list → space settings) for
/// testing that the header's back link and overflow button navigate, matching
/// home_screen_test.dart's `_router`/`_pump` pattern. The task list is
/// *pushed* on top of home, so `context.canPop()` is true — the same shape as
/// production, where the task list is always reached from Home.
GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Scaffold(body: Text('HOME DEST')),
      ),
      GoRoute(
        path: AppRoutes.taskList,
        builder: (context, state) =>
            TaskListScreen(spaceId: state.pathParameters['spaceId']!),
      ),
      GoRoute(
        path: AppRoutes.spaceSettings,
        builder: (context, state) =>
            const Scaffold(body: Text('Space Settings Placeholder')),
      ),
    ],
  );
}

Future<GoRouter> _pumpScreenWithRouter(
  WidgetTester tester, {
  required Stream<List<Task>> stream,
}) async {
  final router = _buildTestRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(_Fakes(), stream: stream, members: const []),
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  router.push(AppRoutes.taskListPath(_spaceId));
  await tester.pumpAndSettle();

  return router;
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
    matching: find.byType(TaskRow),
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

/// The titles of every rendered [TaskRow], in visual order.
List<String> _rowTitles(WidgetTester tester) => tester
    .widgetList<TaskRow>(find.byType(TaskRow))
    .map((row) => row.task.title)
    .toList();

void main() {
  group('TaskListScreen — loading state', () {
    testWidgets('shows a CircularProgressIndicator and no task content while '
        'taskListProvider has not yet emitted', (tester) async {
      await _pumpScreen(tester, stream: const Stream<List<Task>>.empty());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TaskRow), findsNothing);
      expect(find.byType(InlineAddTaskRow), findsNothing);
    });
  });

  group('TaskListScreen — error state', () {
    testWidgets('shows the inline error text when the stream emits an error', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        stream: Stream<List<Task>>.error(Exception('firestore boom')),
      );

      expect(find.text('Something went wrong loading tasks.'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('TaskListScreen — empty state', () {
    testWidgets('shows the add row and the "No tasks yet" hint, and no rows', (
      tester,
    ) async {
      await _pumpScreen(tester, stream: Stream.value(const []));

      expect(find.text('No tasks yet'), findsOneWidget);
      expect(find.byType(TaskRow), findsNothing);
      // A second (bottom) add row on an empty list would read as two
      // identical controls — the empty list deliberately shows only one.
      expect(find.byType(InlineAddTaskRow), findsOneWidget);
    });
  });

  group('TaskListScreen — flat list (issue #55)', () {
    testWidgets('renders one TaskRow per task', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Task one'),
          _task('t2', title: 'Task two'),
          _task('t3', title: 'Task three'),
        ]),
      );

      expect(find.byType(TaskRow), findsNWidgets(3));
      expect(find.text('Task one'), findsOneWidget);
      expect(find.text('Task two'), findsOneWidget);
      expect(find.text('Task three'), findsOneWidget);
    });

    testWidgets(
      'there is no ExpansionTile and no "Completed" section anywhere — '
      "#10's collapsible group was removed entirely",
      (tester) async {
        await _pumpScreen(
          tester,
          stream: Stream.value([
            _task('t1', title: 'Todo task'),
            _task('t2', title: 'Done task', status: TaskStatus.done),
          ]),
        );

        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.textContaining('Completed'), findsNothing);
      },
    );

    testWidgets(
      'a done task stays in place in the emitted order rather than being '
      'grouped at the bottom',
      (tester) async {
        await _pumpScreen(
          tester,
          stream: Stream.value([
            _task('t1', title: 'First todo'),
            _task('t2', title: 'Middle done', status: TaskStatus.done),
            _task('t3', title: 'Last todo'),
          ]),
        );

        expect(_rowTitles(tester), ['First todo', 'Middle done', 'Last todo']);
      },
    );

    testWidgets(
      'the inline add row appears at both the top and the bottom of a '
      'populated list, and there is no FAB',
      (tester) async {
        await _pumpScreen(
          tester,
          stream: Stream.value([_task('t1', title: 'Buy milk')]),
        );

        expect(find.byType(InlineAddTaskRow), findsNWidgets(2));
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );

    testWidgets('a PopupMenuButton exists per row, with no Dismissible '
        'anywhere (swipe gesture never reintroduced)', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Task one'),
          _task('t2', title: 'Task two'),
        ]),
      );

      expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('only the last row is marked isLast, so the list ends without '
        'a dangling separator', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Task one'),
          _task('t2', title: 'Task two'),
        ]),
      );

      final isLastFlags = tester
          .widgetList<TaskRow>(find.byType(TaskRow))
          .map((row) => row.isLast)
          .toList();
      expect(isLastFlags, [false, true]);
    });
  });

  group('TaskListScreen — header', () {
    testWidgets("shows the space's own name once spaceProvider resolves", (
      tester,
    ) async {
      await _pumpScreen(tester, stream: Stream.value(const []));

      expect(find.text('Kitchen'), findsOneWidget);
      expect(find.text('Tasks'), findsNothing);
    });

    testWidgets('falls back to "Tasks" while spaceProvider is still loading', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        stream: Stream.value(const []),
        spaceStream: const Stream<Space?>.empty(),
      );

      expect(find.text('Tasks'), findsOneWidget);
    });

    testWidgets("shows the members' display names joined by ' · '", (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        stream: Stream.value(const []),
        members: const [_memberAda, _memberBea],
      );

      expect(find.text('Ada · Bea'), findsOneWidget);
    });

    testWidgets('omits the subtitle entirely when there are no members yet', (
      tester,
    ) async {
      await _pumpScreen(tester, stream: Stream.value(const []));

      expect(find.textContaining(' · '), findsNothing);
    });

    testWidgets('the back link reads "Home" and pops back to it', (
      tester,
    ) async {
      await _pumpScreenWithRouter(tester, stream: Stream.value(const []));

      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('HOME DEST'), findsOneWidget);
      expect(find.byType(TaskListScreen), findsNothing);
    });

    testWidgets('the share button is present and enabled once the space '
        'has resolved', (tester) async {
      await _pumpScreen(tester, stream: Stream.value(const []));

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.ios_share),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('the share button is disabled while the space is still '
        'loading — there is no invite token to share yet', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value(const []),
        spaceStream: const Stream<Space?>.empty(),
      );

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.ios_share),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'the overflow button pushes the space settings route without throwing',
      (tester) async {
        await _pumpScreenWithRouter(tester, stream: Stream.value(const []));

        expect(find.byIcon(Icons.settings), findsNothing);
        await tester.tap(find.widgetWithIcon(IconButton, Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Space Settings Placeholder'), findsOneWidget);
      },
    );
  });

  group('TaskListScreen — tap-outside unfocus', () {
    testWidgets('tapping empty space reverts an open, empty add row to its '
        'placeholder', (tester) async {
      await _pumpScreen(tester, stream: Stream.value(const []));

      await tester.tap(find.text('Add a task...').first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // The empty-state hint is inert, non-interactive page furniture — a
      // stand-in for "anywhere that isn't a control". Without the screen's
      // tap-outside GestureDetector nothing here would ever drop focus, so
      // the add row would stay stuck as a text field forever (found on
      // device).
      await tester.tapAt(tester.getCenter(find.text('No tasks yet')));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Add a task...'), findsOneWidget);
    });
  });

  group('TaskListScreen — tapping a row', () {
    testWidgets('opens the task detail sheet for that task', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Buy milk', notes: 'Whole milk'),
        ]),
      );

      await tester.tap(find.text('Buy milk'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.text('Edit task'), findsOneWidget);
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

    testWidgets('a done task is also removed without confirmation', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Wash dishes', status: TaskStatus.done),
        ]),
      );

      // Issue #55 — done tasks sit inline in the one flat list, so the row
      // is visible with nothing to expand first.
      await _tapMenuItem(tester, taskTitle: 'Wash dishes', itemLabel: 'Remove');

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
        'real delete exactly once with the correct spaceId/taskId', (
      tester,
    ) async {
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

  group('TaskListScreen — Assign menu item', () {
    // Issue #9 — Assign is no longer a stub. It opens the same sheet Edit
    // does (the real "Assign to" avatar row lives there, not in the popup
    // menu itself), so this mirrors the "Edit menu item" test above
    // exactly rather than asserting a stub SnackBar.
    testWidgets('tapping three-dot then Assign opens TaskDetailSheet for '
        'that task', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Buy milk')]),
      );

      await _tapMenuItem(tester, taskTitle: 'Buy milk', itemLabel: 'Assign');

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.text('Edit task'), findsOneWidget);
    });
  });

  group('TaskListScreen — assignee indicator', () {
    testWidgets("shows the assignee's avatar (initial fallback) with a "
        'tooltip of their name when assigneeUid matches a space member', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Buy milk', assigneeUid: _memberBea.uid),
        ]),
        members: const [_memberBea],
      );

      expect(find.byTooltip('Bea'), findsOneWidget);
      expect(find.byTooltip('Unassigned'), findsNothing);
      // No photoUrl on _memberBea — falls back to the initial.
      expect(
        find.descendant(of: find.byTooltip('Bea'), matching: find.text('B')),
        findsOneWidget,
      );
    });

    testWidgets('shows the neutral "Unassigned" indicator (not a warning '
        'color) when assigneeUid is null', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Buy milk')]),
        members: const [_memberBea],
      );

      expect(find.byTooltip('Unassigned'), findsOneWidget);
      expect(find.byTooltip('Bea'), findsNothing);

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Unassigned'),
          matching: find.byIcon(Icons.person_outline),
        ),
      );
      // The AC is explicit that "unassigned" is not a warning state — the
      // icon must use the design system's muted token, never a warning or
      // danger colour.
      final colors = AppColors.of(tester.element(find.byType(TaskListScreen)));
      expect(icon.color, colors.textMuted);
      expect(icon.color, isNot(colors.warning));
      expect(icon.color, isNot(colors.danger));
    });

    testWidgets('also shows "Unassigned" when assigneeUid does not match '
        'any current space member', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Buy milk', assigneeUid: 'uid-gone'),
        ]),
        members: const [_memberBea],
      );

      expect(find.byTooltip('Unassigned'), findsOneWidget);
    });
  });

  group('TaskListScreen — Mark done menu item', () {
    testWidgets('tapping Mark done calls updateStatusProvider with '
        "TaskStatus.done, regardless of the task's current status "
        '(issue #10)', (tester) async {
      final fakes = await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Buy milk', status: TaskStatus.inProgress),
        ]),
      );

      await _tapMenuItem(tester, taskTitle: 'Buy milk', itemLabel: 'Mark done');

      expect(fakes.updateStatusController.updateStatusCallCount, 1);
      expect(fakes.updateStatusController.lastSpaceId, _spaceId);
      expect(fakes.updateStatusController.lastTaskId, 't1');
      expect(fakes.updateStatusController.lastStatus, TaskStatus.done);
      expect(fakes.deleteTaskController.deleteTaskCallCount, 0);
      expect(fakes.addTaskController.addTaskCallCount, 0);
      expect(fakes.updateTaskController.updateTaskCallCount, 0);
    });
  });

  group('TaskListScreen — status icon tap', () {
    testWidgets('tapping the leading status icon on a todo task advances it '
        'to inProgress and does not open the detail sheet (issue #10)', (
      tester,
    ) async {
      final fakes = await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Buy milk')]),
      );

      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();

      expect(fakes.updateStatusController.updateStatusCallCount, 1);
      expect(fakes.updateStatusController.lastSpaceId, _spaceId);
      expect(fakes.updateStatusController.lastTaskId, 't1');
      expect(fakes.updateStatusController.lastStatus, TaskStatus.inProgress);
      expect(find.byType(TaskDetailSheet), findsNothing);
    });

    testWidgets('tapping the leading status icon on a done task wraps it '
        'back to todo, not open the detail sheet — proves the cycle wraps, '
        'not just increments (issue #10)', (tester) async {
      final fakes = await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Buy milk', status: TaskStatus.done),
        ]),
      );

      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();

      expect(fakes.updateStatusController.updateStatusCallCount, 1);
      expect(fakes.updateStatusController.lastSpaceId, _spaceId);
      expect(fakes.updateStatusController.lastTaskId, 't1');
      expect(fakes.updateStatusController.lastStatus, TaskStatus.todo);
      expect(find.byType(TaskDetailSheet), findsNothing);
    });
  });

  group('TaskListScreen — _AnimatedTaskRow entrance animation (issue #11)', () {
    // A full animation-timing test is likely low-value here (the entrance
    // fade/rise is deliberately "subtle" polish, not core logic) — this
    // sticks to two things worth actually locking down: wrapping TaskRow in
    // an animation didn't break its own content, and re-pumping the same
    // (same-keyed) task list doesn't replay the animation on an unrelated
    // rebuild — the exact bug _AnimatedTaskRow's own doc comment describes
    // guarding against.
    testWidgets('row content still renders correctly through the animation '
        'wrapper', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Buy milk', notes: 'Whole milk'),
        ]),
      );

      expect(find.text('Buy milk'), findsOneWidget);
      // Notes live solely in the detail sheet since issue #55 — the row no
      // longer carries a subtitle.
      expect(find.text('Whole milk'), findsNothing);
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(SlideTransition), findsWidgets);
    });

    testWidgets('a rebuild with the same task list (same ValueKey) does not '
        'restart the entrance animation', (tester) async {
      final controller = StreamController<List<Task>>();
      addTearDown(controller.close);
      final task = _task('t1', title: 'Buy milk');
      controller.add([task]);

      await _pumpScreen(tester, stream: controller.stream);
      // Let the one-shot 250ms entrance animation finish.
      await tester.pump(const Duration(milliseconds: 300));

      final fadeBefore = tester
          .widget<FadeTransition>(find.byType(FadeTransition).first)
          .opacity
          .value;
      expect(fadeBefore, 1.0);

      // An unrelated emission of the exact same task (same id, so the same
      // ValueKey) must not remount _AnimatedTaskRow's State, and therefore
      // must not restart the AnimationController.
      controller.add([task]);
      await tester.pump();

      final fadeAfter = tester
          .widget<FadeTransition>(find.byType(FadeTransition).first)
          .opacity
          .value;
      expect(fadeAfter, 1.0);
    });
  });

  group('TaskListScreen — notification auto-open (issue #12)', () {
    testWidgets('openTaskId null (the default) never auto-opens the sheet — '
        'behavior unchanged from before this issue', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([_task('t1', title: 'Buy milk')]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsNothing);
    });

    testWidgets(
      'openTaskId matching a task already in the emitted list opens its '
      'detail sheet automatically, in edit mode',
      (tester) async {
        await _pumpScreen(
          tester,
          stream: Stream.value([_task('t1', title: 'Buy milk')]),
          openTaskId: 't1',
        );
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailSheet), findsOneWidget);
        expect(find.text('Edit task'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find
                    .descendant(
                      of: find.byType(TaskDetailSheet),
                      matching: find.byType(TextField),
                    )
                    .first,
              )
              .controller!
              .text,
          'Buy milk',
        );
      },
    );

    testWidgets('openTaskId not present on the first emission still opens the '
        'sheet once a later emission includes the matching task', (
      tester,
    ) async {
      final controller = StreamController<List<Task>>();
      addTearDown(controller.close);
      final otherTask = _task('other', title: 'Unrelated task');
      final targetTask = _task('t1', title: 'Buy milk');
      controller.add([otherTask]);

      await _pumpScreen(tester, stream: controller.stream, openTaskId: 't1');
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsNothing);

      controller.add([otherTask, targetTask]);
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.text('Edit task'), findsOneWidget);
    });

    testWidgets(
      'does not reopen the sheet on a later stream emission once it has '
      'already auto-opened, even after the user closes it',
      (tester) async {
        final controller = StreamController<List<Task>>();
        addTearDown(controller.close);
        final task = _task('t1', title: 'Buy milk');
        controller.add([task]);

        await _pumpScreen(tester, stream: controller.stream, openTaskId: 't1');
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailSheet), findsOneWidget);

        Navigator.of(tester.element(find.byType(TaskDetailSheet))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailSheet), findsNothing);

        // A later live-stream emission (e.g. an unrelated Firestore update)
        // must not reopen the sheet — the guard fires at most once per
        // screen instance.
        controller.add([task]);
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailSheet), findsNothing);
      },
    );

    testWidgets(
      'a second notification tap for a different task while this exact '
      'screen widget is updated in place opens that task sheet too, not '
      'silently skipped by the first task guard (didUpdateWidget reset)',
      (tester) async {
        final taskA = _task('t1', title: 'Task A');
        final taskB = _task('t2', title: 'Task B');

        await _pumpScreen(
          tester,
          stream: Stream.value([taskA, taskB]),
          openTaskId: 't1',
        );
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailSheet), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find
                    .descendant(
                      of: find.byType(TaskDetailSheet),
                      matching: find.byType(TextField),
                    )
                    .first,
              )
              .controller!
              .text,
          'Task A',
        );

        Navigator.of(tester.element(find.byType(TaskDetailSheet))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailSheet), findsNothing);

        // Simulate a second notification tap for a different task while this
        // same screen widget instance is updated in place — pumping a new
        // tree of the same shape (same widget types/positions, no keys)
        // updates the existing State via didUpdateWidget rather than
        // recreating it.
        await tester.pumpWidget(
          ProviderScope(
            overrides: _overrides(
              _Fakes(),
              stream: Stream.value([taskA, taskB]),
              members: const [],
            ),
            child: MaterialApp(
              theme: AppTheme.light,
              home: const TaskListScreen(spaceId: _spaceId, openTaskId: 't2'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailSheet), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find
                    .descendant(
                      of: find.byType(TaskDetailSheet),
                      matching: find.byType(TextField),
                    )
                    .first,
              )
              .controller!
              .text,
          'Task B',
        );
      },
    );
  });

  group('TaskListScreen — dark mode', () {
    testWidgets('renders without exceptions', (tester) async {
      await _pumpScreen(
        tester,
        stream: Stream.value([
          _task('t1', title: 'Buy milk', assigneeUid: _memberBea.uid),
          _task('t2', title: 'Wash dishes', status: TaskStatus.done),
        ]),
        members: const [_memberBea],
        dark: true,
      );

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('Wash dishes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
