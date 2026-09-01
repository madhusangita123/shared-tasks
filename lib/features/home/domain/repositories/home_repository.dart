import 'package:shared_tasks/features/home/domain/entities/home_space.dart';

/// Abstract home interface — `data/` provides the Firestore-backed
/// implementation, `presentation/` only ever talks to this.
abstract interface class HomeRepository {
  /// Emits every space [uid] owns or is a member of, ordered by most
  /// recently updated, and re-emits on every realtime change.
  ///
  /// Not wrapped in [Result] — this is a stream, matching the precedent of
  /// [AuthRepository.authStateChanges] (only Future-returning repository
  /// methods use `Result<T>` in this codebase).
  Stream<List<HomeSpace>> watchUserSpaces(String uid);
}
