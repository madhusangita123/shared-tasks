import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/core/providers/connectivity_provider.dart';
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
      functions: ref.watch(firebaseFunctionsProvider),
    ),
  );
});

/// Emits [spaceId]'s current [Space] (or `null`), for screens that need a
/// single space's own data — e.g. the task list screen's AppBar title.
final spaceProvider = StreamProvider.autoDispose.family<Space?, String>((
  ref,
  spaceId,
) {
  return ref.watch(spacesRepositoryProvider).watchSpace(spaceId);
});

/// Resolves [spaceId]'s current member avatars, automatically re-fetching
/// whenever the space's memberUids changes (e.g. someone joins via an
/// invite link) — this is what makes the member list "realtime" per issue
/// #31's AC, built on top of spaceProvider's existing realtime stream
/// rather than a second Firestore listener.
final spaceMembersProvider = FutureProvider.autoDispose.family<List<MemberAvatar>, String>((
  ref,
  spaceId,
) async {
  final space = ref.watch(spaceProvider(spaceId)).valueOrNull;
  if (space == null) return const [];

  final result = await ref
      .watch(spacesRepositoryProvider)
      .getMemberAvatars(space.memberUids);
  return switch (result) {
    Success(:final data) => data,
    // Re-thrown so this FutureProvider surfaces it as AsyncError, same as
    // before getMemberAvatars was Result-wrapped — SpaceSettingsScreen's
    // `membersState.when(error: ...)` already treats any member-list
    // failure as non-critical and skips it silently.
    Failure(:final failure) => throw failure,
  };
});

/// Open (not-done) task count for [spaceId], read once when the owner taps
/// "Delete space" so the confirmation dialog can say how much is about to
/// be lost.
///
/// Deliberately NOT watched at build time: the dialog is the only consumer,
/// and the Delete button must never be gated on a count that is still
/// loading (or that failed). On failure this throws the [AppFailure] so the
/// caller's own try/catch can fall back to count-free copy.
final openTaskCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  spaceId,
) async {
  final result = await ref
      .watch(spacesRepositoryProvider)
      .countOpenTasks(spaceId: spaceId);
  return switch (result) {
    Success(:final data) => data,
    Failure(:final failure) => throw failure,
  };
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

/// Blocks a space mutation while the device is known to be offline, the
/// same convention [AddTaskController] follows in
/// `tasks_provider.dart`'s `_blockIfOffline` — including failing *open* on
/// an indeterminate (`null`/loading/error) connectivity state rather than
/// blocking a write on a signal we don't actually have.
///
/// Doesn't show a SnackBar of its own: the only caller hands the returned
/// [NetworkFailure] back to [SpaceSettingsScreen], which renders it as
/// inline error text.
bool _isOffline(Ref ref) => ref.read(isOnlineProvider).valueOrNull == false;

/// Drives the owner-only "Delete space" button on [SpaceSettingsScreen].
///
/// `AsyncNotifier<void>` rather than `<bool>`: there's nothing to hold
/// after a successful delete — the screen navigates to Home and the space
/// is gone. `state` exists purely so the button can show an in-flight
/// spinner and an inline error.
class DeleteSpaceController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Returns the [AppFailure] that stopped this particular delete, or
  /// `null` if it succeeded.
  ///
  /// Callers must use this return value rather than reading
  /// [deleteSpaceProvider]'s state once the future resolves — same
  /// convention, and same reason, as [AddTaskController.addTask]: the
  /// provider is shared state and a second call can overwrite `state`
  /// before the first caller resumes. `state` is still set on every path
  /// so the button can render loading/error without the screen holding
  /// local state.
  Future<AppFailure?> deleteSpace(String spaceId) async {
    if (_isOffline(ref)) {
      const failure = NetworkFailure();
      state = AsyncError<void>(failure, StackTrace.current);
      return failure;
    }

    state = const AsyncLoading();
    final result = await ref
        .read(spacesRepositoryProvider)
        .deleteSpace(spaceId: spaceId);
    switch (result) {
      case Success():
        state = const AsyncData(null);
        return null;
      case Failure(:final failure):
        state = AsyncError<void>(failure, StackTrace.current);
        return failure;
    }
  }
}

/// `.autoDispose` — state resets whenever [SpaceSettingsScreen] is
/// unmounted, so reopening settings never shows a previous attempt's
/// error.
final deleteSpaceProvider =
    AutoDisposeAsyncNotifierProvider<DeleteSpaceController, void>(
      DeleteSpaceController.new,
    );
