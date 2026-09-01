// Widget tests for SettingsScreen (issue #21, not the PRD's S-06 — that's
// Space Settings). Controls authStateProvider (to
// drive which AppUser — or none yet — is "signed in") and signOutProvider
// (via a fake AsyncNotifier, mirroring sign_in_screen_test.dart's pattern)
// so every state can be driven without touching real Firebase or Google
// Sign-In.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/auth/presentation/settings_screen.dart';

class _MockHttpClient extends Mock implements HttpClient {}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {}

class _MockHttpClientResponse extends Mock implements HttpClientResponse {}

class _MockHttpHeaders extends Mock implements HttpHeaders {}

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // The user's photoUrl (https://example.com/...) resolves through
    // CircleAvatar's NetworkImage. Rather than let the widget test hit a
    // real (nonexistent, sandboxed) network, every request is served a
    // minimal valid 1x1 transparent PNG so the image decodes cleanly.
    // (A genuine decode-failure path is tested separately, by invoking
    // onBackgroundImageError directly — see the "fails to load" test below
    // — since forcing a real codec failure through this mock isn't
    // reliably driven by pump()'s fake clock.)
    const responseBytes = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
    ];

    final client = _MockHttpClient();
    final request = _MockHttpClientRequest();
    final response = _MockHttpClientResponse();
    final headers = _MockHttpHeaders();

    when(() => client.getUrl(any())).thenAnswer((_) async => request);
    when(() => request.headers).thenReturn(headers);
    when(() => request.close()).thenAnswer((_) async => response);
    when(() => response.contentLength).thenReturn(responseBytes.length);
    when(() => response.statusCode).thenReturn(HttpStatus.ok);
    when(() => response.compressionState)
        .thenReturn(HttpClientResponseCompressionState.notCompressed);
    when(
      () => response.listen(
        any(),
        onDone: any(named: 'onDone'),
        onError: any(named: 'onError'),
        cancelOnError: any(named: 'cancelOnError'),
      ),
    ).thenAnswer((invocation) {
      final onData =
          invocation.positionalArguments[0] as void Function(List<int>);
      final onDone = invocation.namedArguments[#onDone] as void Function()?;
      final onError = invocation.namedArguments[#onError] as Function?;
      final cancelOnError =
          invocation.namedArguments[#cancelOnError] as bool?;

      return Stream<List<int>>.fromIterable([responseBytes]).listen(
        onData,
        onDone: onDone,
        onError: onError,
        cancelOnError: cancelOnError ?? false,
      );
    });

    return client;
  }
}

const _user = AppUser(
  id: 'uid-1',
  displayName: 'Ada Lovelace',
  email: 'ada@example.com',
  photoUrl: 'https://example.com/ada.jpg',
);

const _userNoPhoto = AppUser(
  id: 'uid-2',
  displayName: 'bea torres',
  email: 'bea@example.com',
);

/// A controllable stand-in for [SignOutNotifier].
///
/// - [initialError] makes the notifier's initial state `AsyncError` (as if
///   a previous sign-out attempt failed).
/// - [pending] makes `build()` return a `Future` that never resolves during
///   the test, so the initial state stays `AsyncLoading` — simulating a
///   sign-out attempt in flight.
/// - Neither set → initial state is `AsyncData(null)`, the default state.
///
/// [signOut] is overridden so tapping the button never reaches the real
/// repository/Firebase — it just records that it was called.
class _FakeSignOutNotifier extends SignOutNotifier {
  _FakeSignOutNotifier({this.initialError, this.pending = false});

  final Object? initialError;
  final bool pending;

  bool signOutCalled = false;

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
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

Future<_FakeSignOutNotifier> _pumpScreen(
  WidgetTester tester, {
  AppUser? user = _user,
  bool authLoading = false,
  Object? signOutError,
  bool signOutPending = false,
}) async {
  final notifier = _FakeSignOutNotifier(
    initialError: signOutError,
    pending: signOutPending,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => authLoading
              ? const Stream<AppUser?>.empty()
              : Stream.value(user),
        ),
        signOutProvider.overrideWith(() => notifier),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pump();

  return notifier;
}

void main() {
  final originalHttpOverrides = HttpOverrides.current;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = originalHttpOverrides;
  });

  group('SettingsScreen — profile', () {
    testWidgets('renders the display name and email', (tester) async {
      await _pumpScreen(tester, user: _user);

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
    });

    testWidgets('shows a CircleAvatar with a NetworkImage when photoUrl is '
        'non-null', (tester) async {
      await _pumpScreen(tester, user: _user);

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<NetworkImage>());
      expect(
        (avatar.backgroundImage as NetworkImage).url,
        'https://example.com/ada.jpg',
      );
      expect(avatar.child, isNull);
    });

    testWidgets('falls back to the display name initial when photoUrl is '
        'null', (tester) async {
      await _pumpScreen(tester, user: _userNoPhoto);

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isNull);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
        'falls back to the initials avatar when the profile image fails to '
        'load', (tester) async {
      await _pumpScreen(tester, user: _user);

      // Forcing a real image-decode failure through the HTTP mock is
      // notoriously flaky in widget tests — dart:ui's codec pipeline isn't
      // driven by pump()'s fake clock. Instead, invoke the widget's own
      // onBackgroundImageError callback directly, exactly as the real
      // image stream would when a load genuinely fails.
      final avatarBefore =
          tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatarBefore.onBackgroundImageError, isNotNull);
      avatarBefore.onBackgroundImageError!(
        Exception('decode failed'),
        StackTrace.empty,
      );
      await tester.pump();

      final avatarAfter =
          tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatarAfter.backgroundImage, isNull);
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('SettingsScreen — sign out, default state', () {
    testWidgets('the Sign out button is visible and enabled', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Sign out'), findsOneWidget);
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isFalse);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping Sign out calls signOut on the notifier',
        (tester) async {
      final notifier = await _pumpScreen(tester);

      expect(notifier.signOutCalled, isFalse);
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(notifier.signOutCalled, isTrue);
    });
  });

  group('SettingsScreen — sign out, loading state', () {
    testWidgets('shows the Sign out button in its loading state',
        (tester) async {
      await _pumpScreen(tester, signOutPending: true);

      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('SettingsScreen — sign out, error state', () {
    testWidgets(
        "shows the AppFailure's own message inline, with no dialog or "
        'snackbar', (tester) async {
      const failure = AuthFailure('Sign out failed. Try again.');
      await _pumpScreen(tester, signOutError: failure);

      expect(find.text('Sign out failed. Try again.'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('falls back to a generic message for a non-AppFailure error, '
        'with no dialog or snackbar', (tester) async {
      await _pumpScreen(tester, signOutError: Exception('boom'));

      expect(find.text('Sign out failed. Try again.'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the button stops loading once an error state is shown',
        (tester) async {
      await _pumpScreen(tester, signOutError: const NetworkFailure());

      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isFalse);
    });
  });

  group('SettingsScreen — transient null auth state', () {
    testWidgets('shows a loading indicator instead of the profile UI',
        (tester) async {
      await _pumpScreen(tester, authLoading: true);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    });
  });
}
