// Unit tests for SpacesRepositoryImpl — exercises createSpace against a
// mocktail-mocked SpacesRemoteDatasource. Never touches real Firestore.
//
// Mirrors home_repository_test.dart's pattern of mocking the datasource
// rather than exercising Firestore logic directly, but SpacesRepositoryImpl
// also has real mapping logic of its own (try/catch → Result) unlike
// HomeRepositoryImpl's pure pass-through, so the catch branches are covered
// explicitly here based on spaces_repository_impl.dart's actual catch
// clauses: `on SocketException` → NetworkFailure, `catch (_)` →
// UnknownFailure.
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/spaces/data/spaces_remote_datasource.dart';
import 'package:shared_tasks/features/spaces/data/spaces_repository_impl.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';

class MockSpacesRemoteDatasource extends Mock
    implements SpacesRemoteDatasource {}

Space _space({String id = 'space-1', String name = 'Household'}) {
  return Space(
    id: id,
    name: name,
    ownerUid: 'uid-1',
    memberUids: const ['uid-1'],
    inviteToken: 'token-1',
    inviteExpiresAt: DateTime(2027, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late MockSpacesRemoteDatasource mockDatasource;
  late SpacesRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockSpacesRemoteDatasource();
    repository = SpacesRepositoryImpl(datasource: mockDatasource);
  });

  setUpAll(() {
    registerFallbackValue(_space());
  });

  group('createSpace — success', () {
    test('returns a Success wrapping the exact same Space the datasource '
        'returned', () async {
      final space = _space();
      when(
        () => mockDatasource.createSpace(
          name: any(named: 'name'),
          ownerUid: any(named: 'ownerUid'),
        ),
      ).thenAnswer((_) async => space);

      final result = await repository.createSpace(
        name: 'Household',
        ownerUid: 'uid-1',
      );

      expect(result, isA<Success<Space>>());
      expect((result as Success<Space>).data, same(space));
    });

    test('forwards the exact name and ownerUid arguments to the datasource',
        () async {
      when(
        () => mockDatasource.createSpace(
          name: any(named: 'name'),
          ownerUid: any(named: 'ownerUid'),
        ),
      ).thenAnswer((_) async => _space());

      await repository.createSpace(name: 'Chores', ownerUid: 'uid-42');

      verify(
        () => mockDatasource.createSpace(name: 'Chores', ownerUid: 'uid-42'),
      ).called(1);
    });

    test('does not swap or stale the name and ownerUid across calls',
        () async {
      when(
        () => mockDatasource.createSpace(
          name: any(named: 'name'),
          ownerUid: any(named: 'ownerUid'),
        ),
      ).thenAnswer((_) async => _space());

      await repository.createSpace(name: 'First Space', ownerUid: 'uid-a');
      await repository.createSpace(name: 'Second Space', ownerUid: 'uid-b');

      verify(
        () => mockDatasource.createSpace(
          name: 'First Space',
          ownerUid: 'uid-a',
        ),
      ).called(1);
      verify(
        () => mockDatasource.createSpace(
          name: 'Second Space',
          ownerUid: 'uid-b',
        ),
      ).called(1);
      verifyNever(
        () => mockDatasource.createSpace(name: 'First Space', ownerUid: 'uid-b'),
      );
    });
  });

  group('createSpace — failure', () {
    test('maps a SocketException to a Failure<Space> wrapping NetworkFailure',
        () async {
      when(
        () => mockDatasource.createSpace(
          name: any(named: 'name'),
          ownerUid: any(named: 'ownerUid'),
        ),
      ).thenThrow(const SocketException('no route to host'));

      final result = await repository.createSpace(
        name: 'Household',
        ownerUid: 'uid-1',
      );

      expect(result, isA<Failure<Space>>());
      expect((result as Failure<Space>).failure, isA<NetworkFailure>());
    });

    test('maps an unrelated exception to a Failure<Space> wrapping '
        'UnknownFailure as the fallback', () async {
      when(
        () => mockDatasource.createSpace(
          name: any(named: 'name'),
          ownerUid: any(named: 'ownerUid'),
        ),
      ).thenThrow(Exception('firestore boom'));

      final result = await repository.createSpace(
        name: 'Household',
        ownerUid: 'uid-1',
      );

      expect(result, isA<Failure<Space>>());
      expect((result as Failure<Space>).failure, isA<UnknownFailure>());
    });
  });

  group('getMemberAvatars — success', () {
    test('returns a Success wrapping the exact same list the datasource '
        'returned', () async {
      final avatars = [
        const MemberAvatar(uid: 'uid-1', displayName: 'Ada'),
        const MemberAvatar(
          uid: 'uid-2',
          displayName: 'Bea',
          photoUrl: 'https://example.com/bea.jpg',
        ),
      ];
      when(
        () => mockDatasource.getMemberAvatars(any()),
      ).thenAnswer((_) async => avatars);

      final result = await repository.getMemberAvatars(['uid-1', 'uid-2']);

      expect(result, isA<Success<List<MemberAvatar>>>());
      expect((result as Success<List<MemberAvatar>>).data, same(avatars));
    });

    test('forwards the exact memberUids argument to the datasource',
        () async {
      when(
        () => mockDatasource.getMemberAvatars(any()),
      ).thenAnswer((_) async => const []);

      await repository.getMemberAvatars(['uid-1', 'uid-2']);

      verify(
        () => mockDatasource.getMemberAvatars(['uid-1', 'uid-2']),
      ).called(1);
    });
  });

  group('getMemberAvatars — failure', () {
    test(
      'maps a SocketException to a Failure<List<MemberAvatar>> wrapping '
      'NetworkFailure',
      () async {
        when(
          () => mockDatasource.getMemberAvatars(any()),
        ).thenThrow(const SocketException('no route to host'));

        final result = await repository.getMemberAvatars(['uid-1']);

        expect(result, isA<Failure<List<MemberAvatar>>>());
        expect(
          (result as Failure<List<MemberAvatar>>).failure,
          isA<NetworkFailure>(),
        );
      },
    );

    test(
      'maps an unrelated exception to a Failure<List<MemberAvatar>> '
      'wrapping UnknownFailure as the fallback',
      () async {
        when(
          () => mockDatasource.getMemberAvatars(any()),
        ).thenThrow(Exception('firestore boom'));

        final result = await repository.getMemberAvatars(['uid-1']);

        expect(result, isA<Failure<List<MemberAvatar>>>());
        expect(
          (result as Failure<List<MemberAvatar>>).failure,
          isA<UnknownFailure>(),
        );
      },
    );
  });

  group('deleteSpace — success', () {
    test('returns Success(null) and forwards the spaceId positionally to '
        'the datasource', () async {
      when(() => mockDatasource.deleteSpace(any())).thenAnswer((_) async {});

      final result = await repository.deleteSpace(spaceId: 'space-7');

      expect(result, isA<Success<void>>());
      verify(() => mockDatasource.deleteSpace('space-7')).called(1);
    });
  });

  // _mapFunctionsException, code by code. Each `HttpsError` code the
  // `deleteSpace` callable can raise means a different thing to the owner
  // standing in front of the dialog, and two of them carry a message the
  // screen renders verbatim — so these assert the concrete failure type
  // AND, where there is one, the exact message text.
  group('deleteSpace — FirebaseFunctionsException mapping', () {
    Future<AppFailure> failureFor(String code) async {
      when(
        () => mockDatasource.deleteSpace(any()),
      ).thenThrow(FirebaseFunctionsException(code: code, message: 'raw'));

      final result = await repository.deleteSpace(spaceId: 'space-1');

      expect(result, isA<Failure<void>>());
      return (result as Failure<void>).failure;
    }

    test("'permission-denied' → PermissionFailure (a non-owner caller)",
        () async {
      expect(await failureFor('permission-denied'), isA<PermissionFailure>());
    });

    test("'unauthenticated' → AuthFailure", () async {
      final failure = await failureFor('unauthenticated');

      expect(failure, isA<AuthFailure>());
      expect(failure.message, 'You must be signed in.');
    });

    test("'failed-precondition' → NotFoundFailure saying the space is gone "
        '— this is the code the callable raises when the space genuinely '
        'does not exist', () async {
      final failure = await failureFor('failed-precondition');

      expect(failure, isA<NotFoundFailure>());
      expect(failure.message, 'This space no longer exists.');
    });

    // Regression test for a bug found on-device. 'not-found' from a
    // callable does NOT mean "the space is missing" — the function uses
    // 'failed-precondition' for that. It means the CALLABLE itself could
    // not be reached: not deployed, renamed, or deployed to another
    // region. While it was mapped to NotFoundFailure the app told the
    // owner "This space no longer exists." about a space visible on
    // screen right behind the message. It must stay a generic
    // UnknownFailure, and in particular must never carry the
    // space-is-gone wording.
    test("'not-found' → UnknownFailure, NOT NotFoundFailure: the callable "
        'was unreachable, the space is fine', () async {
      final failure = await failureFor('not-found');

      expect(failure, isA<UnknownFailure>());
      expect(failure, isNot(isA<NotFoundFailure>()));
      expect(failure.message, isNot(contains('no longer exists')));
      expect(failure.message, 'Something went wrong');
    });

    test("'unavailable' → NetworkFailure", () async {
      expect(await failureFor('unavailable'), isA<NetworkFailure>());
    });

    test("'deadline-exceeded' → NetworkFailure", () async {
      expect(await failureFor('deadline-exceeded'), isA<NetworkFailure>());
    });

    test('an unrecognised code falls back to UnknownFailure', () async {
      expect(await failureFor('internal'), isA<UnknownFailure>());
    });
  });

  group('deleteSpace — non-Functions failures', () {
    test('maps a SocketException to NetworkFailure', () async {
      when(
        () => mockDatasource.deleteSpace(any()),
      ).thenThrow(const SocketException('no route to host'));

      final result = await repository.deleteSpace(spaceId: 'space-1');

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).failure, isA<NetworkFailure>());
    });

    test('maps an unrelated exception to UnknownFailure as the fallback',
        () async {
      when(() => mockDatasource.deleteSpace(any())).thenThrow(Exception('boom'));

      final result = await repository.deleteSpace(spaceId: 'space-1');

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).failure, isA<UnknownFailure>());
    });
  });

  group('countOpenTasks', () {
    test('returns a Success wrapping the datasource count', () async {
      when(
        () => mockDatasource.countOpenTasks(spaceId: any(named: 'spaceId')),
      ).thenAnswer((_) async => 3);

      final result = await repository.countOpenTasks(spaceId: 'space-1');

      expect(result, isA<Success<int>>());
      expect((result as Success<int>).data, 3);
    });

    test('passes 0 straight through rather than treating it as absent',
        () async {
      when(
        () => mockDatasource.countOpenTasks(spaceId: any(named: 'spaceId')),
      ).thenAnswer((_) async => 0);

      final result = await repository.countOpenTasks(spaceId: 'space-1');

      expect(result, isA<Success<int>>());
      expect((result as Success<int>).data, 0);
    });

    test('forwards the exact spaceId named argument', () async {
      when(
        () => mockDatasource.countOpenTasks(spaceId: any(named: 'spaceId')),
      ).thenAnswer((_) async => 1);

      await repository.countOpenTasks(spaceId: 'space-42');

      verify(() => mockDatasource.countOpenTasks(spaceId: 'space-42')).called(1);
    });

    // SpacesRemoteDatasource.countOpenTasks swallows everything to 0 by
    // design, so in production this repository's Failure branch is
    // unreachable. It is still asserted here, against an explicitly
    // throwing mock, because the Failure branch is the contract
    // openTaskCountProvider rethrows from — if the datasource ever stops
    // swallowing, this is the behaviour the dialog's count-free fallback
    // depends on.
    test('maps a thrown SocketException to NetworkFailure (unreachable via '
        'the real datasource, which swallows to 0)', () async {
      when(
        () => mockDatasource.countOpenTasks(spaceId: any(named: 'spaceId')),
      ).thenThrow(const SocketException('no route to host'));

      final result = await repository.countOpenTasks(spaceId: 'space-1');

      expect(result, isA<Failure<int>>());
      expect((result as Failure<int>).failure, isA<NetworkFailure>());
    });
  });

}
