// Tests for tasks_provider.dart's `_blockIfOffline` guard — issue #11
// (US-08). That guard is a private function, only reachable through the
// REAL controllers (AddTaskController/UpdateTaskController/
// DeleteTaskController/AssignTaskController/UpdateStatusController), so
// unlike task_list_screen_test.dart / task_detail_sheet_test.dart (which
// both override these providers with fake subclasses that skip the guard
// entirely), this file exercises the real controllers directly against a
// mocktail-mocked TasksRepository, with isOnlineProvider overridden to a
// fixed StreamProvider value.
//
// A real MaterialApp/ScaffoldMessenger is used (via scaffoldMessengerKeyProvider,
// watched the same way App.build watches it) so the offline SnackBar's exact
// text can be asserted, not just inferred from state. Never touches real
// Firebase or Firestore.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/core/providers/connectivity_provider.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/notifications/presentation/providers/foreground_notification_provider.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';

class MockTasksRepository extends Mock implements TasksRepository {}

const _currentUser = AppUser(
  id: 'uid-1',
  displayName: 'Ada',
  email: 'ada@example.com',
);
const _offlineSnackBarText =
    "You're offline — changes can't be saved right now";

/// Pumps a tiny harness — a single button whose `onPressed` calls
/// [onPressed] with the live [WidgetRef] — with [tasksRepositoryProvider]
/// overridden to [repository] and [isOnlineProvider] overridden to a fixed
/// `AsyncData(isOnline)` (via a `Stream.value` StreamProvider override, the
/// standard way to fix a StreamProvider's value in Riverpod tests).
///
/// [captureRef] is set once, synchronously, during the initial build — every
/// test uses it afterward to read controller state and invoke the real
/// controller's mutation method via `ref.read(...)`.
Future<void> _pumpHarness(
  WidgetTester tester, {
  required TasksRepository repository,
  required bool isOnline,
  required void Function(WidgetRef ref) captureRef,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tasksRepositoryProvider.overrideWithValue(repository),
        isOnlineProvider.overrideWith((ref) => Stream.value(isOnline)),
        authStateProvider.overrideWith((ref) => Stream.value(_currentUser)),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          captureRef(ref);
          // Watched here, not merely read lazily inside _blockIfOffline —
          // mirrors app.dart's own App.build, which watches isOnlineProvider
          // (and authStateProvider, transitively via other providers) at
          // the root for exactly this reason: a provider that's only ever
          // `ref.read` for the first time at the moment of a mutation is
          // still AsyncLoading on that very first read, which fails open
          // rather than blocking. Watching both here lets their fixed
          // Stream.value overrides resolve before a test calls a mutation
          // method.
          ref.watch(isOnlineProvider);
          ref.watch(authStateProvider);
          // Also watched here, matching how the real screens/sheet watch
          // these AutoDispose providers to drive their own button/error
          // UI (see TaskDetailSheet/TaskListScreen) — without an active
          // watcher, each is autoDispose and gets torn down the instant
          // its own `ref.read(...).method(...)` call's synchronous portion
          // finishes, so a later `ref.read(xProvider)` in a test would see
          // a freshly-rebuilt AsyncData(null) instead of the state the
          // real method call actually set.
          ref.watch(addTaskProvider);
          ref.watch(updateTaskProvider);
          ref.watch(deleteTaskProvider);
          ref.watch(assignTaskProvider);
          ref.watch(updateStatusProvider);
          return MaterialApp(
            scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
            home: const Scaffold(body: SizedBox()),
          );
        },
      ),
    ),
  );
  // Three pumps: one to let the ProviderScope's initial build settle, two
  // more to let the fixed Stream.value overrides for isOnlineProvider and
  // authStateProvider actually deliver their first emission — each is a
  // StreamProvider, which subscribes only once its own AsyncNotifierProvider-
  // style build() future resolves, so the value isn't necessarily available
  // after a single microtask turn.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(TaskStatus.todo);
  });

  late MockTasksRepository mockRepository;

  setUp(() {
    mockRepository = MockTasksRepository();
  });

  group('AddTaskController.addTask — offline', () {
    testWidgets('never calls the repository, sets state to AsyncError '
        'wrapping NetworkFailure, returns that failure, and deliberately '
        'does NOT show the global offline SnackBar', (tester) async {
      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: false,
        captureRef: (r) => ref = r,
      );

      final failure = await ref
          .read(addTaskProvider.notifier)
          .addTask(spaceId: 'space-1', title: 'Buy milk');
      await tester.pump();

      verifyNever(
        () => mockRepository.addTask(
          spaceId: any(named: 'spaceId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
          createdBy: any(named: 'createdBy'),
        ),
      );
      final state = ref.read(addTaskProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkFailure>());
      // The caller gets the failure back and reports it itself — addTask is
      // the one mutation that passes `announce: false`, because
      // InlineAddTaskRow shows its own SnackBar. Firing the global one too
      // would stack two messages for a single blocked add.
      expect(failure, isA<NetworkFailure>());
      expect(find.text(_offlineSnackBarText), findsNothing);
    });
  });

  group('AddTaskController.addTask — online', () {
    testWidgets('calls the repository normally', (tester) async {
      when(
        () => mockRepository.addTask(
          spaceId: any(named: 'spaceId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
          createdBy: any(named: 'createdBy'),
        ),
      ).thenAnswer((_) async => const Success(null));

      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: true,
        captureRef: (r) => ref = r,
      );

      await ref
          .read(addTaskProvider.notifier)
          .addTask(spaceId: 'space-1', title: 'Buy milk');
      await tester.pump();

      verify(
        () => mockRepository.addTask(
          spaceId: 'space-1',
          title: 'Buy milk',
          notes: null,
          createdBy: 'uid-1',
        ),
      ).called(1);
      expect(ref.read(addTaskProvider).hasError, isFalse);
      expect(find.text(_offlineSnackBarText), findsNothing);
    });
  });

  group('UpdateTaskController.updateTask — offline', () {
    testWidgets('never calls the repository, sets state to AsyncError '
        'wrapping NetworkFailure, and shows the offline SnackBar', (
      tester,
    ) async {
      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: false,
        captureRef: (r) => ref = r,
      );

      await ref
          .read(updateTaskProvider.notifier)
          .updateTask(
            spaceId: 'space-1',
            taskId: 'task-1',
            title: 'Buy oat milk',
          );
      await tester.pump();

      verifyNever(
        () => mockRepository.updateTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
        ),
      );
      final state = ref.read(updateTaskProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkFailure>());
      expect(find.text(_offlineSnackBarText), findsOneWidget);
    });
  });

  group('UpdateTaskController.updateTask — online', () {
    testWidgets('calls the repository normally', (tester) async {
      when(
        () => mockRepository.updateTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => const Success(null));

      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: true,
        captureRef: (r) => ref = r,
      );

      await ref
          .read(updateTaskProvider.notifier)
          .updateTask(
            spaceId: 'space-1',
            taskId: 'task-1',
            title: 'Buy oat milk',
          );
      await tester.pump();

      verify(
        () => mockRepository.updateTask(
          spaceId: 'space-1',
          taskId: 'task-1',
          title: 'Buy oat milk',
          notes: null,
        ),
      ).called(1);
      expect(ref.read(updateTaskProvider).hasError, isFalse);
      expect(find.text(_offlineSnackBarText), findsNothing);
    });
  });

  group('DeleteTaskController.deleteTask — offline', () {
    testWidgets('never calls the repository, sets state to AsyncError '
        'wrapping NetworkFailure, and shows the offline SnackBar', (
      tester,
    ) async {
      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: false,
        captureRef: (r) => ref = r,
      );

      await ref
          .read(deleteTaskProvider.notifier)
          .deleteTask(spaceId: 'space-1', taskId: 'task-1');
      await tester.pump();

      verifyNever(
        () => mockRepository.deleteTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
        ),
      );
      final state = ref.read(deleteTaskProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkFailure>());
      expect(find.text(_offlineSnackBarText), findsOneWidget);
    });
  });

  group('DeleteTaskController.deleteTask — online', () {
    testWidgets('calls the repository normally', (tester) async {
      when(
        () => mockRepository.deleteTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async => const Success(null));

      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: true,
        captureRef: (r) => ref = r,
      );

      await ref
          .read(deleteTaskProvider.notifier)
          .deleteTask(spaceId: 'space-1', taskId: 'task-1');
      await tester.pump();

      verify(
        () => mockRepository.deleteTask(spaceId: 'space-1', taskId: 'task-1'),
      ).called(1);
      expect(ref.read(deleteTaskProvider).hasError, isFalse);
      expect(find.text(_offlineSnackBarText), findsNothing);
    });
  });

  group('AssignTaskController.assignTask — offline', () {
    testWidgets('never calls the repository, sets state to AsyncError '
        'wrapping NetworkFailure, and shows the offline SnackBar', (
      tester,
    ) async {
      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: false,
        captureRef: (r) => ref = r,
      );

      await ref
          .read(assignTaskProvider.notifier)
          .assignTask(
            spaceId: 'space-1',
            taskId: 'task-1',
            assigneeUid: 'uid-2',
          );
      await tester.pump();

      verifyNever(
        () => mockRepository.assignTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          assigneeUid: any(named: 'assigneeUid'),
          assignedByUid: any(named: 'assignedByUid'),
        ),
      );
      final state = ref.read(assignTaskProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkFailure>());
      expect(find.text(_offlineSnackBarText), findsOneWidget);
    });
  });

  group('AssignTaskController.assignTask — online', () {
    testWidgets('calls the repository normally', (tester) async {
      when(
        () => mockRepository.assignTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          assigneeUid: any(named: 'assigneeUid'),
          assignedByUid: any(named: 'assignedByUid'),
        ),
      ).thenAnswer((_) async => const Success(null));

      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: true,
        captureRef: (r) => ref = r,
      );

      await ref
          .read(assignTaskProvider.notifier)
          .assignTask(
            spaceId: 'space-1',
            taskId: 'task-1',
            assigneeUid: 'uid-2',
          );
      await tester.pump();

      verify(
        () => mockRepository.assignTask(
          spaceId: 'space-1',
          taskId: 'task-1',
          assigneeUid: 'uid-2',
          assignedByUid: 'uid-1',
        ),
      ).called(1);
      expect(ref.read(assignTaskProvider).hasError, isFalse);
      expect(find.text(_offlineSnackBarText), findsNothing);
    });
  });

  group('UpdateStatusController.updateStatus — offline', () {
    testWidgets('never calls the repository, sets state to AsyncError '
        'wrapping NetworkFailure, and shows the offline SnackBar', (
      tester,
    ) async {
      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: false,
        captureRef: (r) => ref = r,
      );

      await ref
          .read(updateStatusProvider.notifier)
          .updateStatus(
            spaceId: 'space-1',
            taskId: 'task-1',
            status: TaskStatus.inProgress,
          );
      await tester.pump();

      verifyNever(
        () => mockRepository.updateStatus(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          status: any(named: 'status'),
        ),
      );
      final state = ref.read(updateStatusProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkFailure>());
      expect(find.text(_offlineSnackBarText), findsOneWidget);
    });
  });

  group('UpdateStatusController.updateStatus — online', () {
    testWidgets('calls the repository normally', (tester) async {
      when(
        () => mockRepository.updateStatus(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async => const Success(null));

      late WidgetRef ref;
      await _pumpHarness(
        tester,
        repository: mockRepository,
        isOnline: true,
        captureRef: (r) => ref = r,
      );

      await ref
          .read(updateStatusProvider.notifier)
          .updateStatus(
            spaceId: 'space-1',
            taskId: 'task-1',
            status: TaskStatus.inProgress,
          );
      await tester.pump();

      verify(
        () => mockRepository.updateStatus(
          spaceId: 'space-1',
          taskId: 'task-1',
          status: TaskStatus.inProgress,
        ),
      ).called(1);
      expect(ref.read(updateStatusProvider).hasError, isFalse);
      expect(find.text(_offlineSnackBarText), findsNothing);
    });
  });
}
