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

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
}
