import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';

/// A signed-in user for routes that require authentication to reach.
const _fakeUser =
    AppUser(id: 'uid-1', displayName: 'Ada', email: 'ada@example.com');

/// Default container — `authStateProvider` is not overridden, so it falls
/// through to the real (in tests, erroring) Firebase stream, which
/// `StreamProvider` turns into an `AsyncError` whose `valueOrNull` is null —
/// i.e. it behaves as "signed out" for `redirect`'s purposes.
ProviderContainer _signedOutContainer() => ProviderContainer();

/// A container with `authStateProvider` overridden to a signed-in user, so
/// `redirect` lets protected routes through instead of bouncing to
/// `/signin`.
ProviderContainer _signedInContainer() => ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_fakeUser)),
      ],
    );

/// Pumps [container] into a `MaterialApp.router` shell and settles it.
///
/// `routerProvider` now returns one long-lived `GoRouter` for the life of
/// the provider — auth changes re-run `redirect` via `refreshListenable`
/// rather than rebuilding the router — so a single pump is enough; there's
/// no second, "now-current" router instance to re-fetch.
Future<GoRouter> _pumpRouter(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return router;
}

void main() {
  group('routerProvider navigation', () {
    testWidgets(
        'sign-in route renders the real sign-in screen when signed out',
        (tester) async {
      final container = _signedOutContainer();
      addTearDown(container.dispose);
      await _pumpRouter(tester, container);

      expect(find.text('SharedTasks'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets(
        'unauthenticated visit to a protected route redirects to sign-in',
        (tester) async {
      final container = _signedOutContainer();
      addTearDown(container.dispose);
      final router = await _pumpRouter(tester, container);

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('home route renders the real home screen when signed in',
        (tester) async {
      final container = _signedInContainer();
      addTearDown(container.dispose);
      final router = await _pumpRouter(tester, container);

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      // userSpacesProvider isn't overridden here, so — same as
      // authStateProvider in `_signedOutContainer` — it falls through to
      // the real (in tests, erroring) Firestore call, which StreamProvider
      // turns into an AsyncError. The screen itself (app bar title, FAB)
      // still renders regardless of that data state.
      expect(find.text('SharedTasks'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets(
        'create space route renders its placeholder screen when signed in',
        (tester) async {
      final container = _signedInContainer();
      addTearDown(container.dispose);
      final router = await _pumpRouter(tester, container);

      router.go(AppRoutes.createSpace);
      await tester.pumpAndSettle();

      expect(find.text('Create space'), findsWidgets);
    });

    testWidgets(
        'task list route renders the real task list screen when signed in',
        (tester) async {
      final container = _signedInContainer();
      addTearDown(container.dispose);
      final router = await _pumpRouter(tester, container);

      router.go(AppRoutes.taskListPath('space42'));
      await tester.pumpAndSettle();

      // taskListProvider isn't overridden here, so — same reasoning as
      // userSpacesProvider in the home route test above — it falls through
      // to the real (in tests, erroring) Firestore call, which
      // StreamProvider turns into an AsyncError. The screen itself (app
      // bar title, FAB) still renders regardless of that data state.
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets(
        'space settings route extracts spaceId from the path when signed in',
        (tester) async {
      final container = _signedInContainer();
      addTearDown(container.dispose);
      final router = await _pumpRouter(tester, container);

      router.go(AppRoutes.spaceSettingsPath('space42'));
      await tester.pumpAndSettle();

      expect(find.text('Space settings — space42'), findsWidgets);
    });

    testWidgets(
        'join space route renders the real join space screen when signed in',
        (tester) async {
      final container = _signedInContainer();
      addTearDown(container.dispose);
      final router = await _pumpRouter(tester, container);

      router.go(AppRoutes.joinSpacePath('tok-999'));
      await tester.pump();
      // Lets the route's page transition animation finish without using
      // pumpAndSettle() (which would otherwise hang on
      // JoinSpaceScreen's indefinitely-animating CircularProgressIndicator).
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('settings route renders the real settings screen when signed in',
        (tester) async {
      final container = _signedInContainer();
      addTearDown(container.dispose);
      final router = await _pumpRouter(tester, container);

      router.go(AppRoutes.settings);
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('unauthenticated visit to settings redirects to sign-in',
        (tester) async {
      final container = _signedOutContainer();
      addTearDown(container.dispose);
      final router = await _pumpRouter(tester, container);

      router.go(AppRoutes.settings);
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    group('raw external deep-link URI normalization', () {
      // A `sharedtasks://join/{token}` deep link can reach this router as a
      // full external URI — scheme and all — rather than the app-relative
      // path AppRoutes.joinSpacePath builds, depending on which mechanism
      // actually delivers it (Flutter's own built-in deep-link routing, or
      // app_links). `redirect` must normalize it to the real route before
      // go_router's route matching runs, or it fails with
      // "GoException: no routes for location: sharedtasks://join/...".
      testWidgets(
          'a raw sharedtasks://join/{token} URI reaches JoinSpaceScreen when '
          'signed in', (tester) async {
        final container = _signedInContainer();
        addTearDown(container.dispose);
        final router = await _pumpRouter(tester, container);

        router.go('sharedtasks://join/tok-raw-999');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets(
          'a raw sharedtasks://join/{token} URI redirects to sign-in first '
          'when signed out', (tester) async {
        final container = _signedOutContainer();
        addTearDown(container.dispose);
        final router = await _pumpRouter(tester, container);

        router.go('sharedtasks://join/tok-raw-999');
        await tester.pumpAndSettle();

        expect(find.text('Continue with Google'), findsOneWidget);
      });

      testWidgets(
          'a sharedtasks:// URI with a host other than join does not match '
          'the join-space normalization', (tester) async {
        final container = _signedInContainer();
        addTearDown(container.dispose);
        final router = await _pumpRouter(tester, container);

        router.go('sharedtasks://somethingelse/tok-raw-999');
        await tester.pumpAndSettle();

        expect(find.text('Page Not Found'), findsOneWidget);
      });
    });
  });
}
