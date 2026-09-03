import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';

/// Abstract invite interface — `data/` provides the Firestore- and Cloud
/// Functions-backed implementation, `presentation/` only ever talks to
/// this.
abstract interface class InviteRepository {
  /// Regenerates [spaceId]'s invite token and resets its expiry to
  /// `AppConstants.inviteLinkValidity` from now — a plain client-side
  /// Firestore write (`firestore.rules` grants any member update rights on
  /// their own space; [callerUid] is checked against the space's owner at
  /// the application level so "owner only" is actually enforced, not just
  /// implied by which button a screen shows). The previous token becomes
  /// immediately unusable: `joinSpaceByToken` looks up a space by exact
  /// token match, so once the doc is overwritten, the old value matches
  /// nothing.
  ///
  /// `Success(invite)` — regenerated.
  /// `Failure(PermissionFailure)` — [callerUid] isn't the space's owner.
  /// `Failure(...)` — another real error to surface inline.
  Future<Result<Invite>> regenerateInvite({
    required String spaceId,
    required String callerUid,
  });

  /// Calls the `joinSpaceByToken` Cloud Function (see
  /// `functions/src/joinSpaceByToken.ts`) with [token]. Returns the joined
  /// space's id on success — including the already-a-member case, which the
  /// function itself treats as a silent no-op success rather than an error.
  ///
  /// `Success(spaceId)` — joined (or already a member).
  /// `Failure(...)` — invalid/expired token, not signed in, or another
  /// real error to surface inline.
  Future<Result<String>> joinSpace(String token);
}
