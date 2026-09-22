// Widget tests for StatusPills — issue #56's three-pill replacement for the
// SegmentedButton that used to live inside TaskDetailSheet's private
// `_StatusSection`. The mechanism is unchanged (optimistic `_currentStatus`,
// `_lastConfirmedStatus` rollback on error), so these tests are the former
// "Status section" group from task_detail_sheet_test.dart, re-pointed at the
// extracted widget and re-expressed against the pill styling.
//
// `updateStatusProvider` is overridden with a recording fake
// AutoDisposeAsyncNotifier subclass (same pattern as task_row_test.dart), so
// nothing here touches real Firebase or Firestore.
//
// Every pumped MaterialApp sets `theme: AppTheme.light` — StatusPills reads
// its colours via `AppColors.of(context)`, which null-asserts on a theme with
// no AppColors ThemeExtension registered.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/status_pills.dart';

const _spaceId = 'space-1';
const _taskId = 'task-42';

/// A controllable stand-in for [UpdateStatusController].
///
/// - [initialError] makes the notifier's initial state `AsyncError`, as if a
///   previous write had failed.
/// - [pending] makes `build()` return a never-resolving Future, so the state
///   stays `AsyncLoading` — a write in flight.
/// - [failOnUpdate] makes every [updateStatus] call resolve to `AsyncError`
///   instead of `AsyncData`, which is what drives the rollback path. Mutable
///   so a test can flip it mid-flow (first change succeeds, then fails).
class _FakeUpdateStatusController extends UpdateStatusController {
  _FakeUpdateStatusController({
    this.initialError,
    this.pending = false,
    this.failOnUpdate = false,
  });

  final Object? initialError;
  final bool pending;
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

Future<_FakeUpdateStatusController> _pumpPills(
  WidgetTester tester, {
  TaskStatus initialStatus = TaskStatus.todo,
  _FakeUpdateStatusController? controller,
}) async {
  final statusController = controller ?? _FakeUpdateStatusController();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [updateStatusProvider.overrideWith(() => statusController)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatusPills(
            spaceId: _spaceId,
            taskId: _taskId,
            initialStatus: initialStatus,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return statusController;
}

AppColors _colors(WidgetTester tester) =>
    AppColors.of(tester.element(find.byType(StatusPills)));

/// The pill [Container] wrapping [label] — matched by its padding (set in
/// `_StatusPill`) so no ancestor or nested Container can be picked up by
/// accident.
Container _pill(WidgetTester tester, String label) {
  return tester.widget<Container>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.padding ==
                const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
    ),
  );
}

bool _isActive(WidgetTester tester, String label) {
  final decoration = _pill(tester, label).decoration! as BoxDecoration;
  return decoration.color == _colors(tester).statusActivePillBackground;
}

void main() {
  group('StatusPills — rendering', () {
    testWidgets('renders the section label and all three pills', (
      tester,
    ) async {
      await _pumpPills(tester);

      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('To do'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('the pill matching the initial status is active and the '
        'others are not', (tester) async {
      await _pumpPills(tester, initialStatus: TaskStatus.inProgress);

      final colors = _colors(tester);
      final active = _pill(tester, 'In progress');
      final activeDecoration = active.decoration! as BoxDecoration;
      expect(activeDecoration.color, colors.statusActivePillBackground);
      expect(
        tester.widget<Text>(find.text('In progress')).style!.color,
        colors.statusActivePillText,
      );

      expect(_isActive(tester, 'To do'), isFalse);
      expect(_isActive(tester, 'Done'), isFalse);
      expect(
        tester.widget<Text>(find.text('To do')).style!.color,
        colors.textSecondary,
      );
      expect(
        tester.widget<Text>(find.text('Done')).style!.color,
        colors.textSecondary,
      );
    });

    testWidgets('a todo task activates the "To do" pill', (tester) async {
      await _pumpPills(tester);

      expect(_isActive(tester, 'To do'), isTrue);
      expect(_isActive(tester, 'In progress'), isFalse);
      expect(_isActive(tester, 'Done'), isFalse);
    });

    testWidgets('a done task activates the "Done" pill', (tester) async {
      await _pumpPills(tester, initialStatus: TaskStatus.done);

      expect(_isActive(tester, 'Done'), isTrue);
      expect(_isActive(tester, 'To do'), isFalse);
    });
  });

  group('StatusPills — tapping a pill', () {
    testWidgets('writes the new status with the correct spaceId/taskId', (
      tester,
    ) async {
      final controller = await _pumpPills(tester);

      await tester.tap(find.text('In progress'));
      await tester.pump();

      expect(controller.updateStatusCallCount, 1);
      expect(controller.lastSpaceId, _spaceId);
      expect(controller.lastTaskId, _taskId);
      expect(controller.lastStatus, TaskStatus.inProgress);
    });

    testWidgets('tapping the already-active pill does not write again — '
        '_onStatusSelected returns early when unchanged', (tester) async {
      final controller = await _pumpPills(tester);

      await tester.tap(find.text('To do'));
      await tester.pump();

      expect(controller.updateStatusCallCount, 0);
    });

    testWidgets('the tapped pill becomes active immediately (optimistic '
        'update), before the write resolves', (tester) async {
      // `pending` keeps updateStatusProvider in AsyncLoading forever, so the
      // only thing that could have moved the highlight is the optimistic
      // local `_currentStatus` — not a confirmed write.
      await _pumpPills(
        tester,
        controller: _FakeUpdateStatusController(pending: true),
      );

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(_isActive(tester, 'Done'), isTrue);
      expect(_isActive(tester, 'To do'), isFalse);
    });
  });

  group('StatusPills — error state', () {
    testWidgets('shows the inline error text when the provider has an error', (
      tester,
    ) async {
      await _pumpPills(
        tester,
        controller: _FakeUpdateStatusController(
          initialError: Exception('boom'),
        ),
      );

      expect(find.text('Could not update status. Try again.'), findsOneWidget);
    });

    testWidgets('shows no inline error text in the pristine state', (
      tester,
    ) async {
      await _pumpPills(tester);

      expect(find.text('Could not update status. Try again.'), findsNothing);
    });

    testWidgets('shows no inline error text while a write is still in flight', (
      tester,
    ) async {
      await _pumpPills(
        tester,
        controller: _FakeUpdateStatusController(pending: true),
      );

      expect(find.text('Could not update status. Try again.'), findsNothing);
    });

    testWidgets('rolls the selection back to the previous status when the '
        'write fails', (tester) async {
      await _pumpPills(
        tester,
        controller: _FakeUpdateStatusController(failOnUpdate: true),
      );

      await tester.tap(find.text('Done'));
      // The fake resolves without a real async gap, so the optimistic move
      // and its revert both land in the same pump — what matters is the
      // settled outcome: back on "To do", which is what Firestore still has.
      await tester.pump();

      expect(_isActive(tester, 'To do'), isTrue);
      expect(_isActive(tester, 'Done'), isFalse);
      expect(find.text('Could not update status. Try again.'), findsOneWidget);
    });

    testWidgets('a later failure rolls back to the last *confirmed* status, '
        'not the widget\'s original opening value', (tester) async {
      final controller = await _pumpPills(tester);

      await tester.tap(find.text('In progress'));
      await tester.pump();
      await tester.pump();
      expect(_isActive(tester, 'In progress'), isTrue);

      controller.failOnUpdate = true;
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump();

      expect(_isActive(tester, 'In progress'), isTrue);
      expect(_isActive(tester, 'Done'), isFalse);
      expect(_isActive(tester, 'To do'), isFalse);
    });
  });
}
