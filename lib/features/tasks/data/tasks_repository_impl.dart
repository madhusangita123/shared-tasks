import 'dart:io';

import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/tasks/data/tasks_remote_datasource.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/repositories/tasks_repository.dart';

/// Firestore-backed [TasksRepository]. Never throws — every failure from
/// [TasksRemoteDatasource]'s write methods is caught here and mapped to a
/// [Result].
class TasksRepositoryImpl implements TasksRepository {
  const TasksRepositoryImpl({required TasksRemoteDatasource datasource})
    : _datasource = datasource;

  final TasksRemoteDatasource _datasource;

  @override
  Stream<List<Task>> watchTasks(String spaceId) {
    return _datasource.watchTasks(spaceId);
  }

  @override
  Future<Result<void>> addTask({
    required String spaceId,
    required String title,
    String? notes,
    required String createdBy,
  }) async {
    try {
      await _datasource.addTask(
        spaceId: spaceId,
        title: title,
        notes: notes,
        createdBy: createdBy,
      );
      return const Success(null);
    } on SocketException {
      return const Failure(NetworkFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> updateTask({
    required String spaceId,
    required String taskId,
    required String title,
    String? notes,
  }) async {
    try {
      await _datasource.updateTask(
        spaceId: spaceId,
        taskId: taskId,
        title: title,
        notes: notes,
      );
      return const Success(null);
    } on SocketException {
      return const Failure(NetworkFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> deleteTask({
    required String spaceId,
    required String taskId,
  }) async {
    try {
      await _datasource.deleteTask(spaceId: spaceId, taskId: taskId);
      return const Success(null);
    } on SocketException {
      return const Failure(NetworkFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }
}
