// Widget tests for JoinSpaceScreen (S-07). Controls joinSpaceProvider via a
// fake AutoDisposeAsyncNotifier subclass (mirroring
// create_space_screen_test.dart's _FakeCreateSpaceNotifier pattern) so every
// state can be driven without touching the real repository/Cloud Function.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/features/invite/presentation/join_space_screen.dart';
import 'package:shared_tasks/features/invite/presentation/providers/invite_provider.dart';

/// A controllable stand-in for [JoinSpaceController].
///
/// - [initialError] makes the notifier's initial state `AsyncError` (as if
///   the join attempt made in `initState` had already failed).
/// - [pending] makes `build()` return a `Future` that never resolves during
///   the test, so the initial state stays `AsyncLoading` — simulating a
///   join attempt in flight.
/// - [initialSpaceId] sets the initial `AsyncData` value directly (defaults
///   to `null`, the pristine "no attempt yet" state).
///
/// [join] is overridden so `JoinSpaceScreen.initState` never reaches the
/// real repository/Cloud Function — it just records the call. When
/// [spaceIdOnJoin] is given, it also flips `state` to
/// `AsyncData(spaceIdOnJoin)` the way the real notifier would on a
/// successful join, so navigation can be exercised.
class _FakeJoinSpaceController extends JoinSpaceController {
  _FakeJoinSpaceController({
    this.initialSpaceId,
    this.initialError,
    this.pending = false,
    this.spaceIdOnJoin,
  });

  final String? initialSpaceId;
  final Object? initialError;
  final bool pending;
  final String? spaceIdOnJoin;

  int joinCallCount = 0;
  String? lastToken;

  @override
  FutureOr<String?> build() {
    if (initialError != null) {
      throw initialError!;
    }
    if (pending) {
      return Completer<String?>().future;
    }
    return initialSpaceId;
  }

  @override
  Future<void> join(String token) async {
    joinCallCount++;
    lastToken = token;
    if (spaceIdOnJoin != null) {
      state = AsyncData(spaceIdOnJoin);
    }
  }
}

/// Pumps [JoinSpaceScreen] with [joinSpaceProvider] overridden, inside a
/// plain `MaterialApp` — used for every test that doesn't need to exercise
/// navigation, matching create_space_screen_test.dart's `_pumpScreen`
/// convention.
Future<_FakeJoinSpaceController> _pumpScreen(
  WidgetTester tester, {
  String token = 'some-token',
  String? initialSpaceId,
  Object? initialError,
  bool pending = false,
  String? spaceIdOnJoin,
}) async {
  final notifier = _FakeJoinSpaceController(
    initialSpaceId: initialSpaceId,
    initialError: initialError,
    pending: pending,
    spaceIdOnJoin: spaceIdOnJoin,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [joinSpaceProvider.overrideWith(() => notifier)],
      child: MaterialApp(home: JoinSpaceScreen(token: token)),
    ),
  );
  await tester.pump();

  return notifier;
}

/// A minimal real GoRouter harness (join → home) for testing that a
/// successful join navigates via `context.go`, matching
/// create_space_screen_test.dart's `_buildTestRouter`/
/// `_pumpCreateSpaceScreenWithRouter` pattern.
GoRouter _buildTestRouter(String token) {
  return GoRouter(
    initialLocation: AppRoutes.joinSpacePath(token),
    routes: [
      GoRoute(
        path: AppRoutes.joinSpace,
        builder: (context, state) {
          return JoinSpaceScreen(token: state.pathParameters['token']!);
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) =>
            const Scaffold(body: Text('Home Placeholder')),
      ),
    ],
  );
}

Future<GoRouter> _pumpJoinSpaceScreenWithRouter(
  WidgetTester tester, {
  required _FakeJoinSpaceController notifier,
  String token = 'some-token',
}) async {
  final router = _buildTestRouter(token);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [joinSpaceProvider.overrideWith(() => notifier)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return router;
}

void main() {
  group('JoinSpaceScreen — loading state', () {
    testWidgets('shows a spinner and "Joining..." while state is pristine '
        'or AsyncLoading', (tester) async {
      await _pumpScreen(tester, pending: true);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Joining...'), findsOneWidget);
    });
  });

  group('JoinSpaceScreen — error state', () {
    testWidgets("shows the AppFailure's own message inline, plus a Go to "
        'Home control', (tester) async {
      const failure = NotFoundFailure('This invite link is invalid.');
      await _pumpScreen(tester, initialError: failure);

      expect(find.text('This invite link is invalid.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Go to Home'), findsOneWidget);
    });

    testWidgets('falls back to a generic message for a non-AppFailure '
        'error, plus a Go to Home control', (tester) async {
      await _pumpScreen(tester, initialError: Exception('boom'));

      expect(
        find.text('Could not join this space. Try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Go to Home'), findsOneWidget);
    });
  });

  group('JoinSpaceScreen — success navigation', () {
    testWidgets('navigates via context.go to Home once state becomes '
        'AsyncData(spaceId)', (tester) async {
      final notifier = _FakeJoinSpaceController(spaceIdOnJoin: 'space-99');
      await _pumpJoinSpaceScreenWithRouter(tester, notifier: notifier);
      await tester.pumpAndSettle();

      expect(find.text('Home Placeholder'), findsOneWidget);
    });

    testWidgets('an already-a-member no-op (same success shape) also '
        'navigates to Home', (tester) async {
      final notifier = _FakeJoinSpaceController(spaceIdOnJoin: 'space-1');
      await _pumpJoinSpaceScreenWithRouter(tester, notifier: notifier);
      await tester.pumpAndSettle();

      expect(find.text('Home Placeholder'), findsOneWidget);
    });
  });

  group('JoinSpaceScreen — initState join call', () {
    testWidgets('triggers join(token) exactly once with the token from the '
        'route', (tester) async {
      final notifier = await _pumpScreen(tester, token: 'abc-123');

      expect(notifier.joinCallCount, 1);
      expect(notifier.lastToken, 'abc-123');
    });
  });
}
