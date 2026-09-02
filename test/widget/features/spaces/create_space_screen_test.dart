// Widget tests for CreateSpaceScreen (S-05). Controls authStateProvider (to
// drive which AppUser is "signed in", since CreateSpaceNotifier reads
// ref.read(authStateProvider).valueOrNull?.id) and createSpaceProvider (via
// a fake AsyncNotifier subclass, mirroring settings_screen_test.dart's
// _FakeSignOutNotifier pattern) so every state can be driven without
// touching real Firebase or Firestore.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/core/widgets/app_text_field.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:shared_tasks/features/spaces/presentation/create_space_screen.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';

const _user = AppUser(
  id: 'uid-1',
  displayName: 'Ada Lovelace',
  email: 'ada@example.com',
);

const _validationErrorText =
    'Space name must be ${AppConstants.spaceNameMinLength}–'
    '${AppConstants.spaceNameMaxLength} characters';

Space _space({String id = 'space-1', String name = 'Household'}) {
  return Space(
    id: id,
    name: name,
    ownerUid: 'uid-1',
    memberUids: const ['uid-1'],
    inviteToken: 'token-1',
    inviteExpiresAt: DateTime(2027, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

/// A controllable stand-in for [CreateSpaceNotifier].
///
/// - [initialError] makes the notifier's initial state `AsyncError` (as if
///   a previous creation attempt failed).
/// - [pending] makes `build()` return a `Future` that never resolves during
///   the test, so the initial state stays `AsyncLoading` — simulating a
///   creation attempt in flight.
/// - [initialSpace] sets the initial `AsyncData` value directly (defaults
///   to `null`, the pristine "no attempt yet" state).
///
/// [createSpace] is overridden so tapping Create never reaches the real
/// repository/Firestore — it just records the call. When [spaceOnCreate] is
/// given, it also flips `state` to `AsyncData(spaceOnCreate)` the way the
/// real notifier would on a successful creation, so navigation can be
/// exercised.
class _FakeCreateSpaceNotifier extends CreateSpaceNotifier {
  _FakeCreateSpaceNotifier({
    this.initialSpace,
    this.initialError,
    this.pending = false,
    this.spaceOnCreate,
  });

  final Space? initialSpace;
  final Object? initialError;
  final bool pending;
  final Space? spaceOnCreate;

  int createSpaceCallCount = 0;
  String? lastCreatedName;

  @override
  FutureOr<Space?> build() {
    if (initialError != null) {
      throw initialError!;
    }
    if (pending) {
      return Completer<Space?>().future;
    }
    return initialSpace;
  }

  @override
  Future<void> createSpace(String name) async {
    createSpaceCallCount++;
    lastCreatedName = name;
    if (spaceOnCreate != null) {
      state = AsyncData(spaceOnCreate);
    }
  }
}

/// Pumps [CreateSpaceScreen] with [authStateProvider] and
/// [createSpaceProvider] overridden, inside a plain `MaterialApp` — used for
/// every test that doesn't need to exercise navigation, matching
/// settings_screen_test.dart's `_pumpScreen` convention.
Future<_FakeCreateSpaceNotifier> _pumpScreen(
  WidgetTester tester, {
  AppUser? user = _user,
  Space? initialSpace,
  Object? initialError,
  bool pending = false,
  Space? spaceOnCreate,
}) async {
  final notifier = _FakeCreateSpaceNotifier(
    initialSpace: initialSpace,
    initialError: initialError,
    pending: pending,
    spaceOnCreate: spaceOnCreate,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        createSpaceProvider.overrideWith(() => notifier),
      ],
      child: const MaterialApp(home: CreateSpaceScreen()),
    ),
  );
  await tester.pump();

  return notifier;
}

/// A minimal real GoRouter harness (create space → task list) for testing
/// that a successful creation navigates via pushReplacement, matching
/// home_screen_test.dart's `_buildTestRouter`/`_pumpHomeScreenWithRouter`
/// pattern.
GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: AppRoutes.createSpace,
    routes: [
      GoRoute(
        path: AppRoutes.createSpace,
        builder: (context, state) => const CreateSpaceScreen(),
      ),
      GoRoute(
        path: AppRoutes.taskList,
        builder: (context, state) =>
            const Scaffold(body: Text('Task List Placeholder')),
      ),
    ],
  );
}

Future<GoRouter> _pumpCreateSpaceScreenWithRouter(
  WidgetTester tester, {
  required _FakeCreateSpaceNotifier notifier,
  AppUser? user = _user,
}) async {
  final router = _buildTestRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        createSpaceProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return router;
}

void main() {
  group('CreateSpaceScreen — validation', () {
    testWidgets('submitting an empty name shows the inline validation error '
        'and does not call createSpace', (tester) async {
      final notifier = await _pumpScreen(tester);

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(find.text(_validationErrorText), findsOneWidget);
      expect(notifier.createSpaceCallCount, 0);
    });

    testWidgets('a name below spaceNameMinLength shows the inline '
        'validation error and does not call createSpace', (tester) async {
      final notifier = await _pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(find.text(_validationErrorText), findsOneWidget);
      expect(notifier.createSpaceCallCount, 0);
    });

    testWidgets('a valid name clears any prior validation error and calls '
        'createSpace with the trimmed name', (tester) async {
      final notifier = await _pumpScreen(tester);

      // First trigger a validation error...
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(find.text(_validationErrorText), findsOneWidget);

      // ...then submit a valid, whitespace-padded name.
      await tester.enterText(find.byType(TextField), '  Household  ');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(find.text(_validationErrorText), findsNothing);
      expect(notifier.createSpaceCallCount, 1);
      expect(notifier.lastCreatedName, 'Household');
    });
  });

  group('CreateSpaceScreen — loading state', () {
    testWidgets("the Create AppButton's isLoading is true while state is "
        'AsyncLoading', (tester) async {
      await _pumpScreen(tester, pending: true);

      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isTrue);
    });
  });

  group('CreateSpaceScreen — error state', () {
    testWidgets(
        "shows the AppFailure's own message inline, with no dialog or "
        'snackbar', (tester) async {
      const failure = NetworkFailure();
      await _pumpScreen(tester, initialError: failure);

      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('falls back to the generic message for a non-AppFailure '
        'error, with no dialog or snackbar', (tester) async {
      await _pumpScreen(tester, initialError: Exception('boom'));

      expect(
        find.text('Could not create space. Try again.'),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the button stops loading once an error state is shown',
        (tester) async {
      await _pumpScreen(tester, initialError: const NetworkFailure());

      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isFalse);
    });
  });

  group('CreateSpaceScreen — pristine state', () {
    testWidgets('shows no error and the button is not loading before any '
        'creation attempt', (tester) async {
      await _pumpScreen(tester);

      final textField = tester.widget<AppTextField>(find.byType(AppTextField));
      expect(textField.errorText, isNull);
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isFalse);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('CreateSpaceScreen — success navigation', () {
    testWidgets(
        'navigates via pushReplacement to the task list route for the '
        'created space once state becomes AsyncData(space)', (tester) async {
      final space = _space(id: 'space-99');
      final notifier = _FakeCreateSpaceNotifier(spaceOnCreate: space);
      await _pumpCreateSpaceScreenWithRouter(tester, notifier: notifier);

      await tester.enterText(find.byType(TextField), 'Household');
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('Task List Placeholder'), findsOneWidget);
      expect(notifier.createSpaceCallCount, 1);
    });
  });
}
