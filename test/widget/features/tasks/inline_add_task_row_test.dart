// Widget tests for InlineAddTaskRow — issue #55's replacement for the old
// FAB + modal "add task" flow on TaskListScreen (S-03).
//
// `addTaskProvider` is overridden with a recording fake
// AutoDisposeAsyncNotifier subclass (mirroring
// create_space_screen_test.dart's `_FakeCreateSpaceNotifier` pattern) so
// nothing reaches real Firestore. The fake flips its own `state` through
// AsyncLoading to AsyncData/AsyncError the way the real controller does, and
// returns the failure (or null) the way the real controller does — the widget
// branches on that RETURN VALUE, never on provider state, because the two add
// rows on screen share one `addTaskProvider`.
//
// Every pumped MaterialApp sets `theme: AppTheme.light` — the row reads its
// colours via `AppColors.of(context)`, which null-asserts on a theme with no
// AppColors ThemeExtension registered.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/inline_add_task_row.dart';

const _spaceId = 'space-1';

/// A controllable stand-in for [AddTaskController]. [failure], when set,
/// makes every `addTask` call resolve to `AsyncError` instead of
/// `AsyncData` — the widget's "keep the typed text, show a SnackBar" path.
class _FakeAddTaskController extends AddTaskController {
  _FakeAddTaskController({this.failure});

  final AppFailure? failure;

  int addTaskCallCount = 0;
  String? lastSpaceId;
  String? lastTitle;

  @override
  FutureOr<void> build() {}

  @override
  Future<AppFailure?> addTask({
    required String spaceId,
    required String title,
    String? notes,
  }) async {
    addTaskCallCount++;
    lastSpaceId = spaceId;
    lastTitle = title;

    state = const AsyncLoading();
    // A real await, so the widget's own `await ... addTask(...)` genuinely
    // suspends and resumes rather than completing synchronously.
    await Future<void>.delayed(Duration.zero);
    final error = failure;
    state = error == null
        ? const AsyncData<void>(null)
        : AsyncError<void>(error, StackTrace.current);
    return error;
  }
}

Future<_FakeAddTaskController> _pumpRow(
  WidgetTester tester, {
  AppFailure? failure,
}) async {
  final controller = _FakeAddTaskController(failure: failure);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [addTaskProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: InlineAddTaskRow(spaceId: _spaceId)),
      ),
    ),
  );
  await tester.pump();

  return controller;
}

/// Taps the placeholder row, turning it into the autofocused text field.
Future<void> _startEditing(WidgetTester tester) async {
  await tester.tap(find.text('Add a task...'));
  await tester.pumpAndSettle();
}

/// Presses the keyboard's "done" action on the focused field — the row's
/// only submit path (there's no visible submit button by design).
Future<void> _submit(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

bool _fieldHasFocus(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  group('InlineAddTaskRow — placeholder state', () {
    testWidgets('shows the "Add a task..." placeholder and no text field', (
      tester,
    ) async {
      await _pumpRow(tester);

      expect(find.text('Add a task...'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tapping it reveals an autofocused text field', (tester) async {
      await _pumpRow(tester);
      await _startEditing(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(_fieldHasFocus(tester), isTrue);
    });
  });

  group('InlineAddTaskRow — submitting', () {
    testWidgets('calls addTask with the trimmed title and the right spaceId', (
      tester,
    ) async {
      final controller = await _pumpRow(tester);
      await _startEditing(tester);

      await tester.enterText(find.byType(TextField), '   Buy milk   ');
      await _submit(tester);

      expect(controller.addTaskCallCount, 1);
      expect(controller.lastSpaceId, _spaceId);
      expect(controller.lastTitle, 'Buy milk');
    });

    testWidgets('clears the field but keeps focus after a successful add, so '
        'the next task can be typed straight away', (tester) async {
      await _pumpRow(tester);
      await _startEditing(tester);

      await tester.enterText(find.byType(TextField), 'Buy milk');
      await _submit(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(_fieldText(tester), isEmpty);
      expect(_fieldHasFocus(tester), isTrue);
    });

    testWidgets('an empty submit never calls addTask and keeps the field '
        'focused', (tester) async {
      final controller = await _pumpRow(tester);
      await _startEditing(tester);

      await _submit(tester);

      expect(controller.addTaskCallCount, 0);
      expect(find.byType(TextField), findsOneWidget);
      expect(_fieldHasFocus(tester), isTrue);
    });

    testWidgets('a whitespace-only submit never calls addTask either', (
      tester,
    ) async {
      final controller = await _pumpRow(tester);
      await _startEditing(tester);

      await tester.enterText(find.byType(TextField), '    ');
      await _submit(tester);

      expect(controller.addTaskCallCount, 0);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('InlineAddTaskRow — blur', () {
    testWidgets('blurring an empty field reverts to the placeholder row', (
      tester,
    ) async {
      await _pumpRow(tester);
      await _startEditing(tester);
      expect(find.byType(TextField), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Add a task...'), findsOneWidget);
    });

    testWidgets('blurring a field with text still in it keeps the field (and '
        "the user's words) in place", (tester) async {
      await _pumpRow(tester);
      await _startEditing(tester);
      await tester.enterText(find.byType(TextField), 'Half typed');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(_fieldText(tester), 'Half typed');
    });
  });

  group('InlineAddTaskRow — failure', () {
    testWidgets('a failed add keeps the typed text and surfaces the failure '
        'message in a SnackBar', (tester) async {
      const failure = AuthFailure('You must be signed in.');
      final controller = await _pumpRow(tester, failure: failure);
      await _startEditing(tester);

      await tester.enterText(find.byType(TextField), 'Buy milk');
      await _submit(tester);

      expect(controller.addTaskCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(failure.message), findsOneWidget);
      // The one thing that can't be recovered if it's dropped.
      expect(_fieldText(tester), 'Buy milk');
    });

    testWidgets('a NetworkFailure is reported like any other failure — exactly '
        'one SnackBar, never zero', (tester) async {
      // Both the offline pre-check and a socket error inside the repository
      // surface as a bare NetworkFailure here, and the row can't tell them
      // apart. It must therefore always report it: addTask passes
      // `announce: false` to _blockIfOffline so this is the only message,
      // which also means suppressing it here would leave a repository-
      // originated network error completely silent.
      final controller = await _pumpRow(
        tester,
        failure: const NetworkFailure(),
      );
      await _startEditing(tester);

      await tester.enterText(find.byType(TextField), 'Buy milk');
      await _submit(tester);

      expect(controller.addTaskCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      // Still treated as a failure in every other respect: the text stays.
      expect(_fieldText(tester), 'Buy milk');
    });

    testWidgets('an unmapped failure surfaces its own generic message', (
      tester,
    ) async {
      await _pumpRow(tester, failure: const UnknownFailure());
      await _startEditing(tester);

      await tester.enterText(find.byType(TextField), 'Buy milk');
      await _submit(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(_fieldText(tester), 'Buy milk');
    });
  });
}
