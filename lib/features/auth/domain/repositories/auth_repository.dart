import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';

/// Abstract auth interface — `data/` provides the Firebase-backed
/// implementation, `presentation/` only ever talks to this.
abstract interface class AuthRepository {
  /// Signs in with the native Google account picker.
  ///
  /// `Success(user)` — signed in.
  /// `Success(null)` — the user dismissed the picker; treat as silent,
  /// show no error.
  /// `Failure(...)` — a real error to surface inline.
  Future<Result<AppUser?>> signInWithGoogle();

  /// Signs out of both Firebase Auth and Google Sign-In.
  Future<Result<void>> signOut();

  /// Emits the current [AppUser] whenever auth state changes, or `null`
  /// when signed out. Drives router redirects and session persistence.
  Stream<AppUser?> get authStateChanges;
}
