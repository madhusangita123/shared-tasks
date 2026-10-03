// Tests for DeleteSpaceController (spaces_provider.dart) — issue #64.
//
// Lives under test/widget/ rather than test/unit/ for the same reason
// tasks_provider_offline_test.dart does: the offline guard it exercises is a
// private function only reachable through the REAL controller, and keeping
// an AutoDispose provider alive long enough to read its state back needs a
// pumped widget with an active watcher. space_settings_screen_test.dart
// overrides this provider with a fake, so nothing there touches the real
// controller at all.
//
// Mocks SpacesRepository with mocktail and fixes isOnlineProvider with a
// StreamProvider override. Never touches real Firebase.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/core/providers/connectivity_provider.dart';
import 'package:shared_tasks/features/spaces/domain/repositories/spaces_repository.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';

class MockSpacesRepository extends Mock implements SpacesRepository {}

/// Pumps a minimal harness that watches [deleteSpaceProvider] (so the
/// autoDispose controller survives between a method call and a later state
/// read) and [isOnlineProvider] (so its fixed `Stream.value` override has
/// actually delivered a value before any delete is attempted — an
/// unresolved StreamProvider is AsyncLoading, which is itself one of the
/// cases under test and must not leak into the others).
///
/// [onlineStream] of `null` leaves isOnlineProvider un-overridden only when
/// [indeterminate] handling is driven by [onlineStream] itself, so every
/// test passes a stream explicitly.
Future<WidgetRef> _pumpHarness(
  WidgetTester tester, {
  required SpacesRepository repository,
  required Stream<bool> onlineStream,
}) async {
  WidgetRef? captured;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spacesRepositoryProvider.overrideWithValue(repository),
        isOnlineProvider.overrideWith((ref) => onlineStream),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          ref.watch(isOnlineProvider);
          ref.watch(deleteSpaceProvider);
          return const MaterialApp(home: Scaffold(body: SizedBox()));
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();

  return captured!;
}

void main() {
  late MockSpacesRepository mockRepository;

  setUp(() {
    mockRepository = MockSpacesRepository();
  });

  group('DeleteSpaceController.deleteSpace — online', () {
    testWidgets('on success returns null, leaves state AsyncData, and calls '
        'the repository once with the spaceId', (tester) async {
      when(
        () => mockRepository.deleteSpace(spaceId: any(named: 'spaceId')),
      ).thenAnswer((_) async => const Success<void>(null));

      final ref = await _pumpHarness(
        tester,
        repository: mockRepository,
        onlineStream: Stream.value(true),
      );

      final failure = await ref
          .read(deleteSpaceProvider.notifier)
          .deleteSpace('space-7');
      await tester.pump();

      expect(failure, isNull);
      final state = ref.read(deleteSpaceProvider);
      expect(state.hasError, isFalse);
      expect(state.isLoading, isFalse);
      verify(() => mockRepository.deleteSpace(spaceId: 'space-7')).called(1);
    });

    testWidgets('on failure returns that exact failure and leaves state '
        'AsyncError wrapping it', (tester) async {
      const expected = PermissionFailure();
      when(
        () => mockRepository.deleteSpace(spaceId: any(named: 'spaceId')),
      ).thenAnswer((_) async => const Failure<void>(expected));

      final ref = await _pumpHarness(
        tester,
        repository: mockRepository,
        onlineStream: Stream.value(true),
      );

      final failure = await ref
          .read(deleteSpaceProvider.notifier)
          .deleteSpace('space-1');
      await tester.pump();

      expect(failure, same(expected));
      final state = ref.read(deleteSpaceProvider);
      expect(state.hasError, isTrue);
      expect(state.error, same(expected));
    });

    testWidgets('sets state to AsyncLoading while the delete is in flight',
        (tester) async {
      final completer = Completer<Result<void>>();
      when(
        () => mockRepository.deleteSpace(spaceId: any(named: 'spaceId')),
      ).thenAnswer((_) => completer.future);

      final ref = await _pumpHarness(
        tester,
        repository: mockRepository,
        onlineStream: Stream.value(true),
      );

      final pending = ref
          .read(deleteSpaceProvider.notifier)
          .deleteSpace('space-1');
      await tester.pump();

      expect(ref.read(deleteSpaceProvider).isLoading, isTrue);

      completer.complete(const Success<void>(null));
      expect(await pending, isNull);
    });
  });

  group('DeleteSpaceController.deleteSpace — offline guard', () {
    testWidgets('returns NetworkFailure, sets AsyncError, and NEVER calls '
        'the repository when the device is known to be offline',
        (tester) async {
      when(
        () => mockRepository.deleteSpace(spaceId: any(named: 'spaceId')),
      ).thenAnswer((_) async => const Success<void>(null));

      final ref = await _pumpHarness(
        tester,
        repository: mockRepository,
        onlineStream: Stream.value(false),
      );

      final failure = await ref
          .read(deleteSpaceProvider.notifier)
          .deleteSpace('space-1');
      await tester.pump();

      expect(failure, isA<NetworkFailure>());
      final state = ref.read(deleteSpaceProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkFailure>());
      // The point of the guard: no write is even attempted. Firestore's
      // offline persistence would otherwise resolve it locally and report
      // success.
      verifyNever(
        () => mockRepository.deleteSpace(spaceId: any(named: 'spaceId')),
      );
    });

    // `_isOffline` is `valueOrNull == false`, i.e. it fails OPEN on an
    // indeterminate connectivity signal. That is deliberate, and matches
    // tasks_provider.dart's `_blockIfOffline`: a delete the owner asked
    // for is not blocked on a signal we do not actually have. These two
    // tests exist so that behaviour cannot be quietly "fixed" into
    // fail-closed.
    testWidgets('still attempts the delete while connectivity is unresolved '
        '(AsyncLoading) — fails OPEN', (tester) async {
      when(
        () => mockRepository.deleteSpace(spaceId: any(named: 'spaceId')),
      ).thenAnswer((_) async => const Success<void>(null));

      final ref = await _pumpHarness(
        tester,
        repository: mockRepository,
        // Never emits, so isOnlineProvider stays AsyncLoading with a null
        // valueOrNull.
        onlineStream: const Stream<bool>.empty(),
      );
      expect(ref.read(isOnlineProvider).valueOrNull, isNull);

      final failure = await ref
          .read(deleteSpaceProvider.notifier)
          .deleteSpace('space-1');

      expect(failure, isNull);
      verify(() => mockRepository.deleteSpace(spaceId: 'space-1')).called(1);
    });

    testWidgets('still attempts the delete when the connectivity stream '
        'itself errored — fails OPEN', (tester) async {
      when(
        () => mockRepository.deleteSpace(spaceId: any(named: 'spaceId')),
      ).thenAnswer((_) async => const Success<void>(null));

      final ref = await _pumpHarness(
        tester,
        repository: mockRepository,
        onlineStream: Stream<bool>.error(Exception('connectivity boom')),
      );
      expect(ref.read(isOnlineProvider).hasError, isTrue);
      expect(ref.read(isOnlineProvider).valueOrNull, isNull);

      final failure = await ref
          .read(deleteSpaceProvider.notifier)
          .deleteSpace('space-1');

      expect(failure, isNull);
      verify(() => mockRepository.deleteSpace(spaceId: 'space-1')).called(1);
    });
  });
}
