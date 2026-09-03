// Unit tests for InviteRepositoryImpl — exercises regenerateInvite and
// joinSpace against a mocktail-mocked InviteRemoteDatasource. Never touches
// real Firestore or Cloud Functions.
//
// Mirrors spaces_repository_test.dart's pattern of mocking the datasource
// rather than exercising Firestore/Functions logic directly. joinSpace has
// an extra catch clause ahead of the generic ones — `on
// FirebaseFunctionsException`, mapping `.code` per
// invite_repository_impl.dart's `_mapFunctionsException` — covered here for
// each code the joinSpaceByToken Cloud Function is documented to throw (see
// functions/src/joinSpaceByToken.ts): `unauthenticated`, `invalid-argument`,
// `not-found`, `failed-precondition`, plus one unrecognized code.
// regenerateInvite has its own `on PermissionDeniedException` clause,
// covering the datasource's application-level owner check (see that
// exception's doc comment in invite_remote_datasource.dart).
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/invite/data/invite_remote_datasource.dart';
import 'package:shared_tasks/features/invite/data/invite_repository_impl.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';

class MockInviteRemoteDatasource extends Mock
    implements InviteRemoteDatasource {}

Invite _invite({String spaceId = 'space-1', String token = 'token-1'}) {
  return Invite(spaceId: spaceId, token: token, expiresAt: DateTime(2027, 1, 1));
}

/// [FirebaseFunctionsException]'s generative constructor is `@protected` —
/// only reachable from within `cloud_functions_platform_interface` or a
/// subclass, confirmed by reading the installed
/// `cloud_functions_platform_interface` package source
/// (`lib/src/firebase_functions_exception.dart`). A test-only subclass is
/// the straightforward way to construct one with an arbitrary `.code` for
/// these tests.
class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException(String code)
    : super(code: code, message: 'test message');
}

void main() {
  late MockInviteRemoteDatasource mockDatasource;
  late InviteRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockInviteRemoteDatasource();
    repository = InviteRepositoryImpl(datasource: mockDatasource);
  });

  setUpAll(() {
    registerFallbackValue(_invite());
  });

  group('regenerateInvite — success', () {
    test('returns a Success wrapping the exact same Invite the datasource '
        'returned', () async {
      final invite = _invite();
      when(
        () => mockDatasource.regenerateInvite(
          spaceId: any(named: 'spaceId'),
          callerUid: any(named: 'callerUid'),
        ),
      ).thenAnswer((_) async => invite);

      final result = await repository.regenerateInvite(
        spaceId: 'space-1',
        callerUid: 'owner-uid',
      );

      expect(result, isA<Success<Invite>>());
      expect((result as Success<Invite>).data, same(invite));
    });

    test('forwards the exact spaceId and callerUid arguments to the '
        'datasource', () async {
      when(
        () => mockDatasource.regenerateInvite(
          spaceId: any(named: 'spaceId'),
          callerUid: any(named: 'callerUid'),
        ),
      ).thenAnswer((_) async => _invite());

      await repository.regenerateInvite(
        spaceId: 'space-42',
        callerUid: 'owner-uid-42',
      );

      verify(
        () => mockDatasource.regenerateInvite(
          spaceId: 'space-42',
          callerUid: 'owner-uid-42',
        ),
      ).called(1);
    });
  });

  group('regenerateInvite — failure', () {
    test('maps a PermissionDeniedException to a Failure<Invite> wrapping '
        'PermissionFailure', () async {
      when(
        () => mockDatasource.regenerateInvite(
          spaceId: any(named: 'spaceId'),
          callerUid: any(named: 'callerUid'),
        ),
      ).thenThrow(const PermissionDeniedException());

      final result = await repository.regenerateInvite(
        spaceId: 'space-1',
        callerUid: 'not-the-owner',
      );

      expect(result, isA<Failure<Invite>>());
      expect((result as Failure<Invite>).failure, isA<PermissionFailure>());
    });

    test(
        'maps a SocketException to a Failure<Invite> wrapping NetworkFailure',
        () async {
      when(
        () => mockDatasource.regenerateInvite(
          spaceId: any(named: 'spaceId'),
          callerUid: any(named: 'callerUid'),
        ),
      ).thenThrow(const SocketException('no route to host'));

      final result = await repository.regenerateInvite(
        spaceId: 'space-1',
        callerUid: 'owner-uid',
      );

      expect(result, isA<Failure<Invite>>());
      expect((result as Failure<Invite>).failure, isA<NetworkFailure>());
    });

    test('maps an unrelated exception to a Failure<Invite> wrapping '
        'UnknownFailure as the fallback', () async {
      when(
        () => mockDatasource.regenerateInvite(
          spaceId: any(named: 'spaceId'),
          callerUid: any(named: 'callerUid'),
        ),
      ).thenThrow(Exception('firestore boom'));

      final result = await repository.regenerateInvite(
        spaceId: 'space-1',
        callerUid: 'owner-uid',
      );

      expect(result, isA<Failure<Invite>>());
      expect((result as Failure<Invite>).failure, isA<UnknownFailure>());
    });
  });

  group('joinSpace — success', () {
    test('returns a Success wrapping the exact spaceId the datasource '
        'returned', () async {
      when(
        () => mockDatasource.joinSpace(any()),
      ).thenAnswer((_) async => 'space-1');

      final result = await repository.joinSpace('token-1');

      expect(result, isA<Success<String>>());
      expect((result as Success<String>).data, 'space-1');
    });

    test('forwards the exact token argument to the datasource', () async {
      when(
        () => mockDatasource.joinSpace(any()),
      ).thenAnswer((_) async => 'space-1');

      await repository.joinSpace('token-abc');

      verify(() => mockDatasource.joinSpace('token-abc')).called(1);
    });
  });

  group('joinSpace — FirebaseFunctionsException failures', () {
    test('maps "unauthenticated" to a Failure<String> wrapping AuthFailure',
        () async {
      when(() => mockDatasource.joinSpace(any())).thenThrow(
        _TestFirebaseFunctionsException('unauthenticated'),
      );

      final result = await repository.joinSpace('token-1');

      expect(result, isA<Failure<String>>());
      expect((result as Failure<String>).failure, isA<AuthFailure>());
    });

    test('maps "invalid-argument" to a Failure<String> wrapping '
        'NotFoundFailure with the invalid-link message', () async {
      when(() => mockDatasource.joinSpace(any())).thenThrow(
        _TestFirebaseFunctionsException('invalid-argument'),
      );

      final result = await repository.joinSpace('token-1');

      expect(result, isA<Failure<String>>());
      final failure = (result as Failure<String>).failure;
      expect(failure, isA<NotFoundFailure>());
      expect(failure.message, 'This invite link is invalid.');
    });

    test('maps "not-found" to a Failure<String> wrapping NotFoundFailure '
        'with the invalid-link message', () async {
      when(() => mockDatasource.joinSpace(any())).thenThrow(
        _TestFirebaseFunctionsException('not-found'),
      );

      final result = await repository.joinSpace('token-1');

      expect(result, isA<Failure<String>>());
      final failure = (result as Failure<String>).failure;
      expect(failure, isA<NotFoundFailure>());
      expect(failure.message, 'This invite link is invalid.');
    });

    test('maps "failed-precondition" to a Failure<String> wrapping '
        'NotFoundFailure with the expired-link message', () async {
      when(() => mockDatasource.joinSpace(any())).thenThrow(
        _TestFirebaseFunctionsException('failed-precondition'),
      );

      final result = await repository.joinSpace('token-1');

      expect(result, isA<Failure<String>>());
      final failure = (result as Failure<String>).failure;
      expect(failure, isA<NotFoundFailure>());
      expect(failure.message, 'This invite link has expired.');
    });

    test('maps an unrecognized code to a Failure<String> wrapping '
        'UnknownFailure as the fallback', () async {
      when(() => mockDatasource.joinSpace(any())).thenThrow(
        _TestFirebaseFunctionsException('internal'),
      );

      final result = await repository.joinSpace('token-1');

      expect(result, isA<Failure<String>>());
      expect((result as Failure<String>).failure, isA<UnknownFailure>());
    });
  });

  group('joinSpace — generic failure', () {
    test('maps an unrelated exception to a Failure<String> wrapping '
        'UnknownFailure as the fallback', () async {
      when(
        () => mockDatasource.joinSpace(any()),
      ).thenThrow(Exception('functions boom'));

      final result = await repository.joinSpace('token-1');

      expect(result, isA<Failure<String>>());
      expect((result as Failure<String>).failure, isA<UnknownFailure>());
    });
  });
}
