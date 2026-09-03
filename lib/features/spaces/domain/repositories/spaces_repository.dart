import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';

/// Abstract spaces interface — `data/` provides the Firestore-backed
/// implementation, `presentation/` only ever talks to this.
abstract interface class SpacesRepository {
  /// Creates a new space owned by [ownerUid], with [ownerUid] as its sole
  /// initial member — private by default until explicitly shared (see #7).
  ///
  /// `Success(space)` — created.
  /// `Failure(...)` — a real error to surface inline.
  Future<Result<Space>> createSpace({
    required String name,
    required String ownerUid,
  });

  /// Emits [spaceId]'s current [Space] on every realtime change, or `null`
  /// if the doc doesn't exist or fails to load — never throws, never a
  /// [Result] (matches [HomeRepository.watchUserSpaces]'s raw-`Stream`
  /// convention for read-only listeners). Used to show a space's own name
  /// (e.g. the task list screen's AppBar title) without a separate
  /// one-shot fetch.
  Stream<Space?> watchSpace(String spaceId);

  /// Fetches each member's display-facing public profile (name + photo) for
  /// [memberUids], in parallel. A single member lookup failing
  /// (missing/unreadable doc) just skips that member's avatar rather than
  /// failing the whole call — only a call-level failure (e.g. no network)
  /// surfaces as `Failure(...)`, matching every other Future-returning
  /// method on this interface.
  ///
  /// `Success(avatars)` — one entry per resolvable member (may be a subset
  /// of [memberUids] if some lookups were skipped).
  /// `Failure(...)` — the caller should treat member enrichment as
  /// unavailable, not block on it.
  Future<Result<List<MemberAvatar>>> getMemberAvatars(
    List<String> memberUids,
  );
}
