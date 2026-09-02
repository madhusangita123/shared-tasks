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
}
