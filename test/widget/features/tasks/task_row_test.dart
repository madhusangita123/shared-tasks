// Widget tests for TaskRow — issue #55's flat restyle of the former private
// `_TaskRow` card on TaskListScreen (S-03).
//
// TaskRow is a ConsumerWidget that resolves `Task.assigneeUid` through
// `spaceMembersProvider` and writes status changes through
// `updateStatusProvider`, so both are overridden here — the members provider
// with a plain list, the status controller with a recording fake
// (mirroring task_list_screen_test.dart's `_FakeUpdateStatusController`).
// Never touches real Firebase or Firestore.
//
// Every pumped MaterialApp sets `theme: AppTheme.light` — TaskRow reads its
// colours via `AppColors.of(context)`, which null-asserts on a theme that
// has no AppColors ThemeExtension registered (see
// home_screen_test.dart for the same pattern).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/home/presentation/widgets/member_avatar.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/task_row.dart';

const _spaceId = 'space-1';
const _memberBea = MemberAvatar(uid: 'uid-2', displayName: 'Bea');

Task _task({
  String id = 't1',
  String title = 'Buy milk',
  TaskStatus status = TaskStatus.todo,
  String? assigneeUid,
}) {
  return Task(
    id: id,
    spaceId: _spaceId,
    title: title,
    status: status,
    assigneeUid: assigneeUid,
    createdBy: 'uid-1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

/// A controllable stand-in for [UpdateStatusController] — records the
/// arguments of every status write the row triggers.
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

class _Harness {
  _Harness(this.statusController);

  final _FakeUpdateStatusController statusController;
  final List<String> menuSelections = [];
  int tapCount = 0;
}

Future<_Harness> _pumpRow(
  WidgetTester tester, {
  required Task task,
  List<MemberAvatar> members = const [],
  bool isLast = false,
}) async {
  final harness = _Harness(_FakeUpdateStatusController());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spaceMembersProvider.overrideWith((ref, spaceId) async => members),
        updateStatusProvider.overrideWith(() => harness.statusController),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TaskRow(
            task: task,
            spaceId: _spaceId,
            isLast: isLast,
            onTap: () => harness.tapCount++,
            onMenuSelected: harness.menuSelections.add,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // Lets spaceMembersProvider (mocked to resolve synchronously via
  // `async => members`) deliver its data before assertions.
  await tester.pump();

  return harness;
}

AppColors _colors(WidgetTester tester) =>
    AppColors.of(tester.element(find.byType(TaskRow)));

/// The row's own padded, optionally-bottom-bordered [Container] — matched by
/// its padding rather than by position so nested Containers (e.g. inside
/// [MemberAvatarCircle]) can never be picked up by accident.
Container _rowContainer(WidgetTester tester) {
  return tester.widget<Container>(
    find.descendant(
      of: find.byType(TaskRow),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.padding == const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
}

void main() {
  group('TaskRow — title', () {
    testWidgets('renders the task title', (tester) async {
      await _pumpRow(tester, task: _task(title: 'Buy milk'));

      expect(find.text('Buy milk'), findsOneWidget);
    });

    testWidgets('a done task is struck through in the muted colour', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        task: _task(title: 'Buy milk', status: TaskStatus.done),
      );

      final style = tester.widget<Text>(find.text('Buy milk')).style!;
      expect(style.decoration, TextDecoration.lineThrough);
      expect(style.color, _colors(tester).textMuted);
    });

    testWidgets('a not-done task has neither strikethrough nor the muted '
        'colour', (tester) async {
      await _pumpRow(
        tester,
        task: _task(title: 'Buy milk', status: TaskStatus.inProgress),
      );

      final style = tester.widget<Text>(find.text('Buy milk')).style!;
      expect(style.decoration, isNull);
      expect(style.color, _colors(tester).textPrimary);
      expect(style.color, isNot(_colors(tester).textMuted));
    });
  });

  group('TaskRow — status icon', () {
    testWidgets('todo renders an empty ring', (tester) async {
      await _pumpRow(tester, task: _task());

      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('in progress renders the timelapse icon', (tester) async {
      await _pumpRow(tester, task: _task(status: TaskStatus.inProgress));

      expect(find.byIcon(Icons.timelapse), findsOneWidget);
    });

    testWidgets('done renders the filled check', (tester) async {
      await _pumpRow(tester, task: _task(status: TaskStatus.done));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping it on a todo task advances to inProgress without '
        'firing the row tap', (tester) async {
      final harness = await _pumpRow(tester, task: _task());

      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();

      expect(harness.statusController.updateStatusCallCount, 1);
      expect(harness.statusController.lastSpaceId, _spaceId);
      expect(harness.statusController.lastTaskId, 't1');
      expect(harness.statusController.lastStatus, TaskStatus.inProgress);
      expect(harness.tapCount, 0);
    });

    testWidgets('tapping it on an in-progress task advances to done', (
      tester,
    ) async {
      final harness = await _pumpRow(
        tester,
        task: _task(status: TaskStatus.inProgress),
      );

      await tester.tap(find.byIcon(Icons.timelapse));
      await tester.pumpAndSettle();

      expect(harness.statusController.lastStatus, TaskStatus.done);
    });

    testWidgets('tapping it on a done task wraps back to todo — proves the '
        'cycle wraps rather than just incrementing', (tester) async {
      final harness = await _pumpRow(
        tester,
        task: _task(status: TaskStatus.done),
      );

      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();

      expect(harness.statusController.updateStatusCallCount, 1);
      expect(harness.statusController.lastStatus, TaskStatus.todo);
    });
  });

  group('TaskRow — row tap', () {
    testWidgets('tapping the row calls onTap', (tester) async {
      final harness = await _pumpRow(tester, task: _task(title: 'Buy milk'));

      await tester.tap(find.text('Buy milk'));
      await tester.pumpAndSettle();

      expect(harness.tapCount, 1);
      expect(harness.statusController.updateStatusCallCount, 0);
    });
  });

  group('TaskRow — assignee indicator', () {
    testWidgets('an assigned task renders the shared MemberAvatarCircle with '
        "the member's name as its tooltip", (tester) async {
      await _pumpRow(
        tester,
        task: _task(assigneeUid: _memberBea.uid),
        members: const [_memberBea],
      );

      expect(find.byType(MemberAvatarCircle), findsOneWidget);
      expect(find.byTooltip('Bea'), findsOneWidget);
      expect(find.byTooltip('Unassigned'), findsNothing);
    });

    testWidgets('an unassigned task renders the muted person outline, not an '
        'avatar', (tester) async {
      await _pumpRow(tester, task: _task(), members: const [_memberBea]);

      expect(find.byType(MemberAvatarCircle), findsNothing);
      expect(find.byTooltip('Unassigned'), findsOneWidget);

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Unassigned'),
          matching: find.byIcon(Icons.person_outline),
        ),
      );
      // "Unassigned" is an empty slot, never a warning state.
      expect(icon.color, _colors(tester).textMuted);
      expect(icon.color, isNot(_colors(tester).warning));
      expect(icon.color, isNot(_colors(tester).danger));
    });

    testWidgets('an assigneeUid matching no current member also reads as '
        'unassigned', (tester) async {
      await _pumpRow(
        tester,
        task: _task(assigneeUid: 'uid-gone'),
        members: const [_memberBea],
      );

      expect(find.byTooltip('Unassigned'), findsOneWidget);
    });
  });

  group('TaskRow — three-dot menu', () {
    testWidgets('carries all four items', (tester) async {
      await _pumpRow(tester, task: _task());
      await _openMenu(tester);

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Assign'), findsOneWidget);
      expect(find.text('Mark done'), findsOneWidget);
    });

    for (final (label, value) in const [
      ('Edit', 'edit'),
      ('Remove', 'remove'),
      ('Assign', 'assign'),
      ('Mark done', 'mark_done'),
    ]) {
      testWidgets('selecting "$label" calls onMenuSelected with "$value"', (
        tester,
      ) async {
        final harness = await _pumpRow(tester, task: _task());
        await _openMenu(tester);

        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();

        expect(harness.menuSelections, [value]);
      });
    }
  });

  group('TaskRow — bottom rule', () {
    testWidgets('isLast: false draws a 1px bottom border in the border '
        'colour', (tester) async {
      await _pumpRow(tester, task: _task());

      final decoration = _rowContainer(tester).decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.bottom.color, _colors(tester).border);
      expect(border.top, BorderSide.none);
    });

    testWidgets('isLast: true suppresses it, so the list never ends on a '
        'dangling separator', (tester) async {
      await _pumpRow(tester, task: _task(), isLast: true);

      final decoration = _rowContainer(tester).decoration as BoxDecoration?;
      expect(decoration?.border, isNull);
    });
  });
}
