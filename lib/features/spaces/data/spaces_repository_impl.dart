import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:shared_tasks/core/entities/member_avatar.dart';
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
  Future<Result<void>> deleteSpace({required String spaceId}) async {
    try {
      await _datasource.deleteSpace(spaceId);
      return const Success(null);
    } on FirebaseFunctionsException catch (e) {
      return Failure(_mapFunctionsException(e));
    } on SocketException {
      return const Failure(NetworkFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<int>> countOpenTasks({required String spaceId}) async {
    try {
      final count = await _datasource.countOpenTasks(spaceId: spaceId);
      return Success(count);
    } on SocketException {
      return const Failure(NetworkFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  /// Maps `deleteSpace`'s known `HttpsError` codes (see
  /// `functions/src/deleteSpace.ts`) to the [AppFailure] that best
  /// describes them to the caller.
  AppFailure _mapFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'permission-denied':
        return const PermissionFailure();
      case 'unauthenticated':
        return const AuthFailure('You must be signed in.');
      case 'failed-precondition':
        // The space is genuinely gone. Reported rather than swallowed, so
        // the UI doesn't claim a delete it never performed. The screen
        // navigates Home on success only, and Home's stream will have
        // dropped it anyway.
        return const NotFoundFailure('This space no longer exists.');
      case 'not-found':
        // NOT "the space is missing" — `deleteSpace` uses
        // `failed-precondition` for that, precisely so this code is free
        // to mean what it actually indicates here: the callable itself
        // could not be reached (not deployed, renamed, or deployed to a
        // different region). Mapping this to NotFoundFailure made the app
        // tell the owner "This space no longer exists." about a space
        // visible on screen behind the message, which is both wrong and
        // the least alarming possible wording for a total backend
        // outage. The client cannot narrow it further than "something is
        // wrong at our end", so it says that and nothing more.
        return const UnknownFailure();
      case 'unavailable':
      case 'deadline-exceeded':
        return const NetworkFailure();
      default:
        return const UnknownFailure();
    }
  }

  @override
  Stream<Space?> watchSpace(String spaceId) => _datasource.watchSpace(spaceId);

  @override
  Future<Result<List<MemberAvatar>>> getMemberAvatars(
    List<String> memberUids,
  ) async {
    try {
      final avatars = await _datasource.getMemberAvatars(memberUids);
      return Success(avatars);
    } on SocketException {
      return const Failure(NetworkFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }
}
