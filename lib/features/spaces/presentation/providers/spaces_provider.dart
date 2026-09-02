import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/core/providers/firebase_providers.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/spaces/data/spaces_remote_datasource.dart';
import 'package:shared_tasks/features/spaces/data/spaces_repository_impl.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:shared_tasks/features/spaces/domain/repositories/spaces_repository.dart';

final spacesRepositoryProvider = Provider<SpacesRepository>((ref) {
  return SpacesRepositoryImpl(
    datasource: SpacesRemoteDatasource(
      firestore: ref.watch(firestoreProvider),
    ),
  );
});

/// Drives the "Create" button on [CreateSpaceScreen]. `state.value` holds
/// the just-created [Space] once creation succeeds, or `null` before any
/// attempt has been made.
class CreateSpaceNotifier extends AutoDisposeAsyncNotifier<Space?> {
  @override
  FutureOr<Space?> build() => null;

  Future<void> createSpace(String name) async {
    final ownerUid = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerUid == null) {
      state = AsyncError<Space?>(
        const AuthFailure('You must be signed in.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    final result = await ref
        .read(spacesRepositoryProvider)
        .createSpace(name: name, ownerUid: ownerUid);
    state = switch (result) {
      Success(:final data) => AsyncData(data),
      Failure(:final failure) => AsyncError<Space?>(
        failure,
        StackTrace.current,
      ),
    };
  }
}

/// `.autoDispose` — state resets to the pristine `null` build() value
/// whenever [CreateSpaceScreen] is unmounted, so revisiting it later never
/// briefly shows a stale error or a previous attempt's result.
final createSpaceProvider =
    AutoDisposeAsyncNotifierProvider<CreateSpaceNotifier, Space?>(
      CreateSpaceNotifier.new,
    );
