// Unit tests for TasksRepositoryImpl — exercises watchTasks, addTask,
// updateTask, and deleteTask against a mocktail-mocked
// TasksRemoteDatasource. Never touches real Firestore.
//
// watchTasks mirrors home_repository_test.dart's pure pass-through pattern
// exactly (no logic to cover beyond forwarding). addTask/updateTask/
// deleteTask mirror spaces_repository_test.dart's Result<void> success/
// failure mapping pattern — the catch branches are covered explicitly here
// based on tasks_repository_impl.dart's actual catch clauses: `on
// SocketException` → NetworkFailure, `catch (_)` → UnknownFailure.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/tasks/data/tasks_remote_datasource.dart';
import 'package:shared_tasks/features/tasks/data/tasks_repository_impl.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';

class MockTasksRemoteDatasource extends Mock implements TasksRemoteDatasource {}

Task _task(String id, {String spaceId = 'space-1'}) {
  return Task(
    id: id,
    spaceId: spaceId,
    title: 'Task $id',
    status: TaskStatus.todo,
    createdBy: 'uid-1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late MockTasksRemoteDatasource mockDatasource;
  late TasksRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockTasksRemoteDatasource();
    repository = TasksRepositoryImpl(datasource: mockDatasource);
  });

  group('watchTasks', () {
    test("passes through the datasource's emitted values unchanged",
        () async {
      final tasks = [_task('t1'), _task('t2')];
      when(() => mockDatasource.watchTasks(any()))
          .thenAnswer((_) => Stream.value(tasks));

      final emissions = await repository.watchTasks('space-1').toList();

      expect(emissions, [tasks]);
      expect(emissions.single, same(tasks));
    });

    test('passes through every emission from a multi-value stream in order',
        () async {
      final first = [_task('t1')];
      final second = <Task>[];
      final third = [_task('t2'), _task('t3')];
      when(() => mockDatasource.watchTasks(any()))
          .thenAnswer((_) => Stream.fromIterable([first, second, third]));

      final emissions = await repository.watchTasks('space-1').toList();

      expect(emissions, [first, second, third]);
    });

    test('passes through a stream error unchanged', () async {
      when(() => mockDatasource.watchTasks(any()))
          .thenAnswer((_) => Stream.error(Exception('firestore boom')));

      await expectLater(
        repository.watchTasks('space-1'),
        emitsError(isA<Exception>()),
      );
    });

    test('forwards the exact spaceId argument to the datasource', () async {
      when(() => mockDatasource.watchTasks(any()))
          .thenAnswer((_) => const Stream.empty());

      repository.watchTasks('space-42');

      verify(() => mockDatasource.watchTasks('space-42')).called(1);
    });

    test('a different spaceId is forwarded exactly, not a cached/stale one',
        () async {
      when(() => mockDatasource.watchTasks(any()))
          .thenAnswer((_) => const Stream.empty());

      repository.watchTasks('space-a');
      repository.watchTasks('space-b');

      verify(() => mockDatasource.watchTasks('space-a')).called(1);
      verify(() => mockDatasource.watchTasks('space-b')).called(1);
      verifyNever(() => mockDatasource.watchTasks('space-c'));
    });
  });

  group('addTask — success', () {
    test('returns a Success<void>', () async {
      when(
        () => mockDatasource.addTask(
          spaceId: any(named: 'spaceId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
          createdBy: any(named: 'createdBy'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.addTask(
        spaceId: 'space-1',
        title: 'Buy milk',
        createdBy: 'uid-1',
      );

      expect(result, isA<Success<void>>());
    });

    test('forwards the exact spaceId/title/notes/createdBy arguments to the '
        'datasource', () async {
      when(
        () => mockDatasource.addTask(
          spaceId: any(named: 'spaceId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
          createdBy: any(named: 'createdBy'),
        ),
      ).thenAnswer((_) async {});

      await repository.addTask(
        spaceId: 'space-1',
        title: 'Buy milk',
        notes: 'Whole milk',
        createdBy: 'uid-1',
      );

      verify(
        () => mockDatasource.addTask(
          spaceId: 'space-1',
          title: 'Buy milk',
          notes: 'Whole milk',
          createdBy: 'uid-1',
        ),
      ).called(1);
    });

    test('forwards a null notes argument unchanged', () async {
      when(
        () => mockDatasource.addTask(
          spaceId: any(named: 'spaceId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
          createdBy: any(named: 'createdBy'),
        ),
      ).thenAnswer((_) async {});

      await repository.addTask(
        spaceId: 'space-1',
        title: 'Buy milk',
        createdBy: 'uid-1',
      );

      verify(
        () => mockDatasource.addTask(
          spaceId: 'space-1',
          title: 'Buy milk',
          notes: null,
          createdBy: 'uid-1',
        ),
      ).called(1);
    });
  });

  group('addTask — failure', () {
    test('maps a SocketException to a Failure<void> wrapping NetworkFailure',
        () async {
      when(
        () => mockDatasource.addTask(
          spaceId: any(named: 'spaceId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
          createdBy: any(named: 'createdBy'),
        ),
      ).thenThrow(const SocketException('no route to host'));

      final result = await repository.addTask(
        spaceId: 'space-1',
        title: 'Buy milk',
        createdBy: 'uid-1',
      );

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).failure, isA<NetworkFailure>());
    });

    test('maps an unrelated exception to a Failure<void> wrapping '
        'UnknownFailure as the fallback', () async {
      when(
        () => mockDatasource.addTask(
          spaceId: any(named: 'spaceId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
          createdBy: any(named: 'createdBy'),
        ),
      ).thenThrow(Exception('firestore boom'));

      final result = await repository.addTask(
        spaceId: 'space-1',
        title: 'Buy milk',
        createdBy: 'uid-1',
      );

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).failure, isA<UnknownFailure>());
    });
  });

  group('updateTask — success', () {
    test('returns a Success<void>', () async {
      when(
        () => mockDatasource.updateTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.updateTask(
        spaceId: 'space-1',
        taskId: 'task-1',
        title: 'Buy oat milk',
      );

      expect(result, isA<Success<void>>());
    });

    test('forwards the exact spaceId/taskId/title/notes arguments to the '
        'datasource', () async {
      when(
        () => mockDatasource.updateTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async {});

      await repository.updateTask(
        spaceId: 'space-1',
        taskId: 'task-1',
        title: 'Buy oat milk',
        notes: 'From the co-op',
      );

      verify(
        () => mockDatasource.updateTask(
          spaceId: 'space-1',
          taskId: 'task-1',
          title: 'Buy oat milk',
          notes: 'From the co-op',
        ),
      ).called(1);
    });

    test('does not swap or stale arguments across calls', () async {
      when(
        () => mockDatasource.updateTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async {});

      await repository.updateTask(
        spaceId: 'space-1',
        taskId: 'task-1',
        title: 'First title',
      );
      await repository.updateTask(
        spaceId: 'space-2',
        taskId: 'task-2',
        title: 'Second title',
      );

      verify(
        () => mockDatasource.updateTask(
          spaceId: 'space-1',
          taskId: 'task-1',
          title: 'First title',
          notes: null,
        ),
      ).called(1);
      verify(
        () => mockDatasource.updateTask(
          spaceId: 'space-2',
          taskId: 'task-2',
          title: 'Second title',
          notes: null,
        ),
      ).called(1);
    });
  });

  group('updateTask — failure', () {
    test('maps a SocketException to a Failure<void> wrapping NetworkFailure',
        () async {
      when(
        () => mockDatasource.updateTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
        ),
      ).thenThrow(const SocketException('no route to host'));

      final result = await repository.updateTask(
        spaceId: 'space-1',
        taskId: 'task-1',
        title: 'Buy oat milk',
      );

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).failure, isA<NetworkFailure>());
    });

    test('maps an unrelated exception to a Failure<void> wrapping '
        'UnknownFailure as the fallback', () async {
      when(
        () => mockDatasource.updateTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          notes: any(named: 'notes'),
        ),
      ).thenThrow(Exception('firestore boom'));

      final result = await repository.updateTask(
        spaceId: 'space-1',
        taskId: 'task-1',
        title: 'Buy oat milk',
      );

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).failure, isA<UnknownFailure>());
    });
  });

  group('deleteTask — success', () {
    test('returns a Success<void>', () async {
      when(
        () => mockDatasource.deleteTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.deleteTask(
        spaceId: 'space-1',
        taskId: 'task-1',
      );

      expect(result, isA<Success<void>>());
    });

    test('forwards the exact spaceId/taskId arguments to the datasource',
        () async {
      when(
        () => mockDatasource.deleteTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async {});

      await repository.deleteTask(spaceId: 'space-1', taskId: 'task-1');

      verify(
        () => mockDatasource.deleteTask(spaceId: 'space-1', taskId: 'task-1'),
      ).called(1);
    });

    test('does not swap or stale spaceId/taskId across calls', () async {
      when(
        () => mockDatasource.deleteTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async {});

      await repository.deleteTask(spaceId: 'space-a', taskId: 'task-a');
      await repository.deleteTask(spaceId: 'space-b', taskId: 'task-b');

      verify(
        () => mockDatasource.deleteTask(spaceId: 'space-a', taskId: 'task-a'),
      ).called(1);
      verify(
        () => mockDatasource.deleteTask(spaceId: 'space-b', taskId: 'task-b'),
      ).called(1);
      verifyNever(
        () => mockDatasource.deleteTask(spaceId: 'space-a', taskId: 'task-b'),
      );
    });
  });

  group('deleteTask — failure', () {
    test('maps a SocketException to a Failure<void> wrapping NetworkFailure',
        () async {
      when(
        () => mockDatasource.deleteTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenThrow(const SocketException('no route to host'));

      final result = await repository.deleteTask(
        spaceId: 'space-1',
        taskId: 'task-1',
      );

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).failure, isA<NetworkFailure>());
    });

    test('maps an unrelated exception to a Failure<void> wrapping '
        'UnknownFailure as the fallback', () async {
      when(
        () => mockDatasource.deleteTask(
          spaceId: any(named: 'spaceId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenThrow(Exception('firestore boom'));

      final result = await repository.deleteTask(
        spaceId: 'space-1',
        taskId: 'task-1',
      );

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).failure, isA<UnknownFailure>());
    });
  });
}
