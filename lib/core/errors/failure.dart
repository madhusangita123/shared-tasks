/// Base type for all errors surfaced by repositories.
///
/// Repositories never throw — they return a [Result] wrapping either the
/// requested data or a concrete [AppFailure] subtype.
sealed class AppFailure {
  const AppFailure(this.message);

  /// User-facing message describing what went wrong.
  final String message;
}

/// No internet connection, or a request timed out.
final class NetworkFailure extends AppFailure {
  const NetworkFailure() : super('No internet connection');
}

/// Sign-in, sign-out, or session related failure.
final class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

/// The requested document or resource does not exist.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

/// The current user is not allowed to perform the requested action.
final class PermissionFailure extends AppFailure {
  const PermissionFailure() : super('You do not have permission');
}

/// Fallback for any error that doesn't map to a more specific failure.
final class UnknownFailure extends AppFailure {
  const UnknownFailure() : super('Something went wrong');
}
