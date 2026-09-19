// Widget tests for SignInScreen (S-01). Controls signInProvider directly
// via a fake AsyncNotifier so every AsyncValue state (data/loading/error)
// can be driven without touching real Firebase or Google Sign-In.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/auth/presentation/sign_in_screen.dart';
import 'package:shared_tasks/features/auth/presentation/widgets/app_logo.dart';
import 'package:shared_tasks/features/auth/presentation/widgets/google_sign_in_button.dart';

/// A controllable stand-in for [SignInNotifier].
///
/// - [initialError] makes the notifier's initial state `AsyncError` (as if
///   a previous sign-in attempt failed).
/// - [pending] makes `build()` return a `Future` that never resolves during
///   the test, so the initial state stays `AsyncLoading` — simulating a
///   sign-in attempt in flight.
/// - Neither set → initial state is `AsyncData(null)`, the default/success
///   state.
///
/// [signInWithGoogle] is overridden so tapping the button never reaches the
/// real repository/Firebase — it just records that it was called.
class _FakeSignInNotifier extends SignInNotifier {
  _FakeSignInNotifier({this.initialError, this.pending = false});

  final Object? initialError;
  final bool pending;

  bool signInCalled = false;

  @override
  FutureOr<void> build() {
    if (initialError != null) {
      throw initialError!;
    }
    if (pending) {
      return Completer<void>().future;
    }
    return null;
  }

  @override
  Future<void> signInWithGoogle() async {
    signInCalled = true;
  }
}

Future<_FakeSignInNotifier> _pumpScreen(
  WidgetTester tester, {
  Object? initialError,
  bool pending = false,
}) async {
  final notifier = _FakeSignInNotifier(
    initialError: initialError,
    pending: pending,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [signInProvider.overrideWith(() => notifier)],
      child: MaterialApp(theme: AppTheme.light, home: const SignInScreen()),
    ),
  );
  await tester.pump();

  return notifier;
}

void main() {
  group('SignInScreen — default state', () {
    testWidgets(
        'renders the logo, title, tagline, and Continue with Google button',
        (tester) async {
      await _pumpScreen(tester);

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('SharedTasks'), findsOneWidget);
      expect(find.text('Tasks, together.'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleSignInButton), findsOneWidget);
    });

    testWidgets('shows no error text and no separate Retry button',
        (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Retry'), findsNothing);
      expect(find.textContaining('No internet'), findsNothing);
      expect(find.textContaining('Sign in failed'), findsNothing);
    });

    testWidgets('tapping the button calls signInWithGoogle on the notifier',
        (tester) async {
      final notifier = await _pumpScreen(tester);

      expect(notifier.signInCalled, isFalse);
      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();

      expect(notifier.signInCalled, isTrue);
    });
  });

  group('SignInScreen — loading state', () {
    testWidgets('shows the button in its loading state and no error text',
        (tester) async {
      await _pumpScreen(tester, pending: true);

      final button = tester.widget<GoogleSignInButton>(
        find.byType(GoogleSignInButton),
      );
      expect(button.isLoading, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);

      expect(find.textContaining('No internet'), findsNothing);
      expect(find.textContaining('Sign in failed'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('tapping the button while loading does not call signIn',
        (tester) async {
      final notifier = await _pumpScreen(tester, pending: true);

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();

      expect(notifier.signInCalled, isFalse);
    });
  });

  group('SignInScreen — error state', () {
    testWidgets(
        'shows "No internet connection. Try again." inline for a '
        'NetworkFailure, with no dialog, snackbar, or Retry button',
        (tester) async {
      await _pumpScreen(tester, initialError: const NetworkFailure());

      expect(
        find.text('No internet connection. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        "shows the AppFailure's own message inline for a generic auth "
        'failure, with no Retry button', (tester) async {
      const failure = AuthFailure('Sign in failed. Try again.');
      await _pumpScreen(tester, initialError: failure);

      expect(find.text('Sign in failed. Try again.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        'shows the generic fallback message for an error that is not an '
        'AppFailure at all', (tester) async {
      await _pumpScreen(tester, initialError: Exception('boom'));

      expect(find.text('Sign in failed. Try again.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('the button stops loading once an error state is shown',
        (tester) async {
      await _pumpScreen(tester, initialError: const NetworkFailure());

      final button = tester.widget<GoogleSignInButton>(
        find.byType(GoogleSignInButton),
      );
      expect(button.isLoading, isFalse);
    });
  });
}
