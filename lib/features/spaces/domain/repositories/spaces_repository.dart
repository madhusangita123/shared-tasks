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
}
