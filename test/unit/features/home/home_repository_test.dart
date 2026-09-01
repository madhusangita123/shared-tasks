// Unit tests for HomeRepositoryImpl — exercises the thin pass-through in
// lib/features/home/data/home_repository_impl.dart against a
// mocktail-mocked HomeRemoteDatasource. Never touches real Firestore.
//
// HomeRepositoryImpl has exactly one method, watchUserSpaces, which simply
// forwards to the datasource's stream of the same name — the real logic
// (Firestore queries, open-task-count aggregation, member avatar fetching)
// lives in HomeRemoteDatasource and is out of scope here, matching the
// established pattern in auth_repository_test.dart of mocking the
// datasource rather than exercising Firestore query logic in a unit test.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/features/home/data/home_remote_datasource.dart';
import 'package:shared_tasks/features/home/data/home_repository_impl.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';

class MockHomeRemoteDatasource extends Mock implements HomeRemoteDatasource {}

HomeSpace _space(String id, {List<String> memberUids = const ['uid-1']}) {
  return HomeSpace(
    id: id,
    name: 'Space $id',
    memberUids: memberUids,
    openTaskCount: 0,
    updatedAt: DateTime(2026, 1, 1),
    memberAvatars: const [],
  );
}

void main() {
  late MockHomeRemoteDatasource mockDatasource;
  late HomeRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockHomeRemoteDatasource();
    repository = HomeRepositoryImpl(datasource: mockDatasource);
  });

  group('watchUserSpaces', () {
    test("passes through the datasource's emitted values unchanged",
        () async {
      final spaces = [_space('s1'), _space('s2', memberUids: ['uid-1', 'uid-2'])];
      when(() => mockDatasource.watchUserSpaces(any()))
          .thenAnswer((_) => Stream.value(spaces));

      final emissions = await repository.watchUserSpaces('uid-1').toList();

      expect(emissions, [spaces]);
      expect(emissions.single, same(spaces));
    });

    test('passes through every emission from a multi-value stream in order',
        () async {
      final first = [_space('s1')];
      final second = <HomeSpace>[];
      final third = [_space('s2'), _space('s3')];
      when(() => mockDatasource.watchUserSpaces(any()))
          .thenAnswer((_) => Stream.fromIterable([first, second, third]));

      final emissions = await repository.watchUserSpaces('uid-1').toList();

      expect(emissions, [first, second, third]);
    });

    test('passes through a stream error unchanged', () async {
      when(() => mockDatasource.watchUserSpaces(any()))
          .thenAnswer((_) => Stream.error(Exception('firestore boom')));

      await expectLater(
        repository.watchUserSpaces('uid-1'),
        emitsError(isA<Exception>()),
      );
    });

    test('forwards the exact uid argument to the datasource', () async {
      when(() => mockDatasource.watchUserSpaces(any()))
          .thenAnswer((_) => const Stream.empty());

      repository.watchUserSpaces('uid-42');

      verify(() => mockDatasource.watchUserSpaces('uid-42')).called(1);
    });

    test('a different uid is forwarded exactly, not a cached/stale one',
        () async {
      when(() => mockDatasource.watchUserSpaces(any()))
          .thenAnswer((_) => const Stream.empty());

      repository.watchUserSpaces('uid-a');
      repository.watchUserSpaces('uid-b');

      verify(() => mockDatasource.watchUserSpaces('uid-a')).called(1);
      verify(() => mockDatasource.watchUserSpaces('uid-b')).called(1);
      verifyNever(() => mockDatasource.watchUserSpaces('uid-c'));
    });
  });
}
