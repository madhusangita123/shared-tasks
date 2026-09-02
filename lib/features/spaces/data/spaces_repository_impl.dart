import 'dart:io';

import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/spaces/data/spaces_remote_datasource.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:shared_tasks/features/spaces/domain/repositories/spaces_repository.dart';

/// Firestore-backed [SpacesRepository]. Never throws — every failure from
/// [SpacesRemoteDatasource] is caught here and mapped to a [Result].
class SpacesRepositoryImpl implements SpacesRepository {
  const SpacesRepositoryImpl({required SpacesRemoteDatasource datasource})
    : _datasource = datasource;

  final SpacesRemoteDatasource _datasource;

  @override
  Future<Result<Space>> createSpace({
    required String name,
    required String ownerUid,
  }) async {
    try {
      final space = await _datasource.createSpace(
        name: name,
        ownerUid: ownerUid,
      );
      return Success(space);
    } on SocketException {
      return const Failure(NetworkFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Stream<Space?> watchSpace(String spaceId) => _datasource.watchSpace(spaceId);
}
