import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/invite/data/invite_remote_datasource.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';
import 'package:shared_tasks/features/invite/domain/repositories/invite_repository.dart';

/// Firestore- and Cloud Functions-backed [InviteRepository]. Never throws —
/// every failure from [InviteRemoteDatasource] is caught here and mapped to
/// a [Result].
class InviteRepositoryImpl implements InviteRepository {
  const InviteRepositoryImpl({required InviteRemoteDatasource datasource})
    : _datasource = datasource;

  final InviteRemoteDatasource _datasource;

  @override
  Future<Result<Invite>> regenerateInvite({
    required String spaceId,
    required String callerUid,
  }) async {
    try {
      final invite = await _datasource.regenerateInvite(
        spaceId: spaceId,
        callerUid: callerUid,
      );
      return Success(invite);
    } on PermissionDeniedException {
      return const Failure(PermissionFailure());
    } on SocketException {
      return const Failure(NetworkFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<String>> joinSpace(String token) async {
    try {
      final spaceId = await _datasource.joinSpace(token);
      return Success(spaceId);
    } on FirebaseFunctionsException catch (e) {
      return Failure(_mapFunctionsException(e));
    } on SocketException {
      return const Failure(NetworkFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  /// Maps `joinSpaceByToken`'s known `HttpsError` codes (see
  /// `functions/src/joinSpaceByToken.ts`) to the [AppFailure] that best
  /// describes them to the recipient.
  AppFailure _mapFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return const AuthFailure('You must be signed in to join a space.');
      case 'invalid-argument':
      case 'not-found':
        return const NotFoundFailure('This invite link is invalid.');
      case 'failed-precondition':
        return const NotFoundFailure('This invite link has expired.');
      default:
        return const UnknownFailure();
    }
  }
}
