import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/core/providers/firebase_providers.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/invite/data/invite_remote_datasource.dart';
import 'package:shared_tasks/features/invite/data/invite_repository_impl.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';
import 'package:shared_tasks/features/invite/domain/repositories/invite_repository.dart';

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepositoryImpl(
    datasource: InviteRemoteDatasource(
      firestore: ref.watch(firestoreProvider),
      functions: ref.watch(firebaseFunctionsProvider),
    ),
  );
});

/// Drives the "Regenerate link" action (owner only). `state.value` holds the
/// newly-generated [Invite] once regeneration succeeds, or `null` before any
/// attempt has been made.
class RegenerateInviteController extends AutoDisposeAsyncNotifier<Invite?> {
  @override
  FutureOr<Invite?> build() => null;

  Future<void> regenerate(String spaceId) async {
    final callerUid = ref.read(authStateProvider).valueOrNull?.id;
    if (callerUid == null) {
      state = AsyncError<Invite?>(
        const AuthFailure('You must be signed in.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    final result = await ref
        .read(inviteRepositoryProvider)
        .regenerateInvite(spaceId: spaceId, callerUid: callerUid);
    state = switch (result) {
      Success(:final data) => AsyncData(data),
      Failure(:final failure) => AsyncError<Invite?>(
        failure,
        StackTrace.current,
      ),
    };
  }
}

/// `.autoDispose` — state resets to the pristine `null` build() value
/// whenever the owning screen is unmounted, matching `createSpaceProvider`'s
/// convention.
final regenerateInviteProvider =
    AutoDisposeAsyncNotifierProvider<RegenerateInviteController, Invite?>(
      RegenerateInviteController.new,
    );

/// Drives [JoinSpaceScreen]'s join attempt. `state.value` holds the joined
/// space's id once the join succeeds (including the already-a-member
/// no-op), or `null` before any attempt has been made.
class JoinSpaceController extends AutoDisposeAsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<void> join(String token) async {
    state = const AsyncLoading();
    final result = await ref.read(inviteRepositoryProvider).joinSpace(token);
    state = switch (result) {
      Success(:final data) => AsyncData(data),
      Failure(:final failure) => AsyncError<String?>(
        failure,
        StackTrace.current,
      ),
    };
  }
}

final joinSpaceProvider =
    AutoDisposeAsyncNotifierProvider<JoinSpaceController, String?>(
      JoinSpaceController.new,
    );

/// Opens the native share sheet (WhatsApp, iMessage, etc.) with [invite]'s
/// shareable deep link. A plain wrapper function rather than a provider —
/// `share_plus`'s `Share.share()` is a one-shot platform call with no state
/// to track.
///
/// No UI calls this yet — issue #30 builds the capability; wiring an actual
/// Share button into `SpaceSettingsScreen` is issue #31's scope.
Future<void> shareInviteLink(Invite invite) => Share.share(
  invite.shareableLink,
);
