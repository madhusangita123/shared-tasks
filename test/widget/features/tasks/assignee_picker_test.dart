// Widget tests for AssigneePicker — issue #56's extraction of the "Assign to"
// avatar row that used to live inside TaskDetailSheet's private
// `_AssignToSection`. The mechanism is unchanged (signed-in-user-first
// ordering, optimistic `_currentAssigneeUid`, `_lastConfirmedAssigneeUid`
// rollback on error, tap-again-to-unassign), so these tests are the former
// "Assign to section" groups from task_detail_sheet_test.dart, re-pointed at
// the extracted widget.
//
// `assignTaskProvider` is overridden with a recording fake
// AutoDisposeAsyncNotifier subclass, and `authStateProvider` /
// `spaceMembersProvider` with plain values — nothing here touches real
// Firebase or Firestore.
//
// Every pumped MaterialApp sets `theme: AppTheme.light` — AssigneePicker
// reads its colours via `AppColors.of(context)`, which null-asserts on a
// theme with no AppColors ThemeExtension registered.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/assignee_picker.dart';

const _spaceId = 'space-1';
const _taskId = 'task-42';

// The signed-in user is always among the space's own members (as in
// production), and is deliberately placed mid-list so tests verify the
// picker *reorders* them to the front rather than merely preserving an
// already-first position.
const _currentUser = AppUser(
  id: 'uid-1',
  displayName: 'Ada',
  email: 'ada@example.com',
);
const _memberSelf = MemberAvatar(uid: 'uid-1', displayName: 'Ada');
const _memberBea = MemberAvatar(uid: 'uid-2', displayName: 'Bea');
const _memberCleo = MemberAvatar(uid: 'uid-3', displayName: 'Cleo');

/// A controllable stand-in for [AssignTaskController]. `null` is a valid
/// recorded [lastAssigneeUid] (unassign), so [assignTaskCallCount] is what
/// tells a test whether a call happened at all.
class _FakeAssignTaskController extends AssignTaskController {
  _FakeAssignTaskController({
    this.initialError,
    this.pending = false,
    this.failOnAssign = false,
  });

  final Object? initialError;
  final bool pending;

  /// When true, every [assignTask] call resolves to `AsyncError` instead of
  /// `AsyncData` — the rollback path. Mutable so a test can flip it mid-flow.
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

Future<_FakeAssignTaskController> _pumpPicker(
  WidgetTester tester, {
  String? initialAssigneeUid,
  List<MemberAvatar> members = const [_memberSelf, _memberBea],
  _FakeAssignTaskController? controller,
  AppUser currentUser = _currentUser,
  Completer<List<MemberAvatar>>? membersCompleter,
  Object? membersError,
}) async {
  final assignController = controller ?? _FakeAssignTaskController();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assignTaskProvider.overrideWith(() => assignController),
        authStateProvider.overrideWith((ref) => Stream.value(currentUser)),
        spaceMembersProvider.overrideWith((ref, spaceId) async {
          if (membersError != null) throw membersError;
          if (membersCompleter != null) return membersCompleter.future;
          return members;
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AssigneePicker(
            spaceId: _spaceId,
            taskId: _taskId,
            initialAssigneeUid: initialAssigneeUid,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // Lets spaceMembersProvider (mocked to resolve synchronously via
  // `async => members`) deliver its data before assertions.
  await tester.pump();

  return assignController;
}

AppColors _colors(WidgetTester tester) =>
    AppColors.of(tester.element(find.byType(AssigneePicker)));

Finder _optionFor(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

/// The selection-ring [Container] of [label]'s option — see
/// `_AssigneeOption`. Its border is [AppColors.primary] when selected and
/// transparent otherwise (always 2px, so selection never resizes the row).
BoxDecoration _ringFor(WidgetTester tester, String label) {
  final option = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.width == 56,
    ),
  );
  final container = find.descendant(
    of: option,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container && widget.padding == const EdgeInsets.all(2),
    ),
  );
  return tester.widget<Container>(container).decoration! as BoxDecoration;
}

bool _isSelected(WidgetTester tester, String label) =>
    _ringFor(tester, label).border!.top.color == _colors(tester).primary;

void main() {
  group('AssigneePicker — rendering', () {
    testWidgets('renders the section label, one option per member, and '
        '"None"', (tester) async {
      await _pumpPicker(tester, members: const [_memberSelf, _memberBea]);

      expect(find.text('ASSIGN TO'), findsOneWidget);
      expect(find.text('Me'), findsOneWidget);
      expect(find.text('Bea'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('the signed-in user is first and labelled "Me", never by '
        'their own display name', (tester) async {
      await _pumpPicker(
        tester,
        members: const [_memberBea, _memberSelf, _memberCleo],
      );

      expect(find.text('Me'), findsOneWidget);
      expect(find.text('Ada'), findsNothing);

      final meDx = tester.getTopLeft(find.text('Me')).dx;
      expect(meDx, lessThan(tester.getTopLeft(find.text('Bea')).dx));
      expect(meDx, lessThan(tester.getTopLeft(find.text('Cleo')).dx));
    });

    testWidgets('the "None" option renders the person-outline icon (not a '
        'dashed circle) — matching TaskRow\'s unassigned indicator', (
      tester,
    ) async {
      await _pumpPicker(tester);

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });
  });

  group('AssigneePicker — selection ring', () {
    testWidgets('the currently-assigned member has the primary ring and '
        'others do not', (tester) async {
      await _pumpPicker(
        tester,
        initialAssigneeUid: _memberBea.uid,
        members: const [_memberSelf, _memberBea, _memberCleo],
      );

      expect(_isSelected(tester, 'Bea'), isTrue);
      expect(_isSelected(tester, 'Me'), isFalse);
      expect(_isSelected(tester, 'Cleo'), isFalse);
      expect(_isSelected(tester, 'None'), isFalse);
    });

    testWidgets('"None" carries the ring when the task is unassigned', (
      tester,
    ) async {
      await _pumpPicker(tester);

      expect(_isSelected(tester, 'None'), isTrue);
      expect(_isSelected(tester, 'Me'), isFalse);
      expect(_isSelected(tester, 'Bea'), isFalse);
    });
  });

  group('AssigneePicker — tapping an option', () {
    testWidgets('tapping a member assigns them with the correct '
        'spaceId/taskId', (tester) async {
      final controller = await _pumpPicker(tester);

      await tester.tap(_optionFor('Bea'));
      await tester.pump();

      expect(controller.assignTaskCallCount, 1);
      expect(controller.lastSpaceId, _spaceId);
      expect(controller.lastTaskId, _taskId);
      expect(controller.lastAssigneeUid, _memberBea.uid);
    });

    testWidgets('tapping "Me" assigns the signed-in user\'s own uid', (
      tester,
    ) async {
      final controller = await _pumpPicker(tester);

      await tester.tap(_optionFor('Me'));
      await tester.pump();

      expect(controller.assignTaskCallCount, 1);
      expect(controller.lastAssigneeUid, _memberSelf.uid);
    });

    testWidgets('tapping the currently-assigned member again unassigns '
        '(a null assigneeUid)', (tester) async {
      final controller = await _pumpPicker(
        tester,
        initialAssigneeUid: _memberBea.uid,
      );

      await tester.tap(_optionFor('Bea'));
      await tester.pump();

      expect(controller.assignTaskCallCount, 1);
      expect(controller.lastAssigneeUid, isNull);
    });

    testWidgets('tapping "None" on an assigned task unassigns it', (
      tester,
    ) async {
      final controller = await _pumpPicker(
        tester,
        initialAssigneeUid: _memberBea.uid,
      );

      await tester.tap(_optionFor('None'));
      await tester.pump();

      expect(controller.assignTaskCallCount, 1);
      expect(controller.lastAssigneeUid, isNull);
    });

    testWidgets('tapping "None" on an already-unassigned task does nothing '
        '— _onNoneTapped returns early', (tester) async {
      final controller = await _pumpPicker(tester);

      await tester.tap(_optionFor('None'));
      await tester.pump();

      expect(controller.assignTaskCallCount, 0);
    });

    testWidgets('the ring moves to the tapped member immediately '
        '(optimistic), before the write resolves', (tester) async {
      // `pending` keeps assignTaskProvider in AsyncLoading forever, so the
      // only thing that could have moved the ring is the optimistic local
      // `_currentAssigneeUid` — not a confirmed write.
      await _pumpPicker(
        tester,
        controller: _FakeAssignTaskController(pending: true),
      );

      await tester.tap(_optionFor('Bea'));
      await tester.pump();

      expect(_isSelected(tester, 'Bea'), isTrue);
      expect(_isSelected(tester, 'None'), isFalse);
    });
  });

  group('AssigneePicker — error state', () {
    testWidgets('shows the inline error text when the provider has an error', (
      tester,
    ) async {
      await _pumpPicker(
        tester,
        controller: _FakeAssignTaskController(initialError: Exception('boom')),
      );

      expect(
        find.text('Could not update assignee. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shows no inline error text in the pristine state', (
      tester,
    ) async {
      await _pumpPicker(tester);

      expect(find.text('Could not update assignee. Try again.'), findsNothing);
    });

    testWidgets('shows no inline error text while a write is still in flight', (
      tester,
    ) async {
      await _pumpPicker(
        tester,
        controller: _FakeAssignTaskController(pending: true),
      );

      expect(find.text('Could not update assignee. Try again.'), findsNothing);
    });

    testWidgets('rolls the ring back to the previous assignee when the write '
        'fails', (tester) async {
      await _pumpPicker(
        tester,
        controller: _FakeAssignTaskController(failOnAssign: true),
        initialAssigneeUid: _memberBea.uid,
        members: const [_memberSelf, _memberBea, _memberCleo],
      );

      await tester.tap(_optionFor('Cleo'));
      // The fake resolves without a real async gap, so the optimistic move
      // and its revert both land in the same pump — what matters is the
      // settled outcome: the ring is back on Bea, who is still actually
      // assigned in Firestore.
      await tester.pump();

      expect(_isSelected(tester, 'Bea'), isTrue);
      expect(_isSelected(tester, 'Cleo'), isFalse);
      expect(
        find.text('Could not update assignee. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a later failure rolls back to the last *confirmed* '
        'assignee, not the widget\'s original opening value', (tester) async {
      final controller = await _pumpPicker(
        tester,
        members: const [_memberSelf, _memberBea, _memberCleo],
      );

      // First tap succeeds — Bea becomes the confirmed assignee.
      await tester.tap(_optionFor('Bea'));
      await tester.pump();
      await tester.pump();
      expect(_isSelected(tester, 'Bea'), isTrue);

      // Second tap fails — rolls back to Bea, not all the way to unassigned.
      controller.failOnAssign = true;
      await tester.tap(_optionFor('Cleo'));
      await tester.pump();
      await tester.pump();

      expect(_isSelected(tester, 'Bea'), isTrue);
      expect(_isSelected(tester, 'Cleo'), isFalse);
      expect(_isSelected(tester, 'None'), isFalse);
    });
  });

  group('AssigneePicker — spaceMembersProvider states', () {
    testWidgets('shows a progress indicator while members are loading', (
      tester,
    ) async {
      final completer = Completer<List<MemberAvatar>>();
      addTearDown(() => completer.complete(const []));
      await _pumpPicker(tester, membersCompleter: completer);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('None'), findsNothing);
      // The section label still renders — only the row itself is deferred.
      expect(find.text('ASSIGN TO'), findsOneWidget);
    });

    testWidgets('renders nothing (not an exception) when the member fetch '
        'fails — the rest of the sheet stays usable', (tester) async {
      await _pumpPicker(tester, membersError: Exception('members boom'));

      expect(find.text('ASSIGN TO'), findsOneWidget);
      expect(find.text('None'), findsNothing);
      expect(find.text('Me'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
