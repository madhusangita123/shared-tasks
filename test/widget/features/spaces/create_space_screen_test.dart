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
import 'package:shared_tasks/core/theme/app_theme.dart';
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
      child: MaterialApp(
        theme: AppTheme.light,
        home: const CreateSpaceScreen(),
      ),
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
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) =>
            const Scaffold(body: Text('Home Placeholder')),
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
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump();
  return router;
}

Finder get _field => find.byType(TextField);
Finder get _createText => find.text('Create space');

bool _enabled(WidgetTester tester) {
  final ink = tester.widget<InkWell>(
    find
        .ancestor(
          of: _createText.evaluate().isEmpty
              ? find.byType(CircularProgressIndicator)
              : _createText,
          matching: find.byType(InkWell),
        )
        .first,
  );
  return ink.onTap != null;
}

void main() {
  testWidgets('autofocuses the text field', (tester) async {
    await _pumpScreen(tester);
    expect(tester.widget<TextField>(_field).focusNode!.hasFocus, isTrue);
  });

  testWidgets('shows header texts and hint', (tester) async {
    await _pumpScreen(tester);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('New space'), findsOneWidget);
    expect(find.text('Give it a name'), findsOneWidget);
    expect(find.text('e.g. House chores'), findsOneWidget);
  });

  group('validation', () {
    testWidgets('empty: no error, disabled', (tester) async {
      await _pumpScreen(tester);
      expect(find.text(_validationErrorText), findsNothing);
      expect(_enabled(tester), isFalse);
    });

    testWidgets('2 chars: error + disabled', (tester) async {
      final n = await _pumpScreen(tester);
      await tester.enterText(_field, 'ab');
      await tester.pump();
      expect(find.text(_validationErrorText), findsOneWidget);
      expect(_enabled(tester), isFalse);
      await tester.tap(_createText);
      expect(n.createSpaceCallCount, 0);
    });

    testWidgets('3 chars: valid', (tester) async {
      await _pumpScreen(tester);
      await tester.enterText(_field, 'abc');
      await tester.pump();
      expect(find.text(_validationErrorText), findsNothing);
      expect(_enabled(tester), isTrue);
    });

    testWidgets('40 chars: valid', (tester) async {
      await _pumpScreen(tester);
      await tester.enterText(_field, 'a' * 40);
      await tester.pump();
      expect(find.text(_validationErrorText), findsNothing);
      expect(_enabled(tester), isTrue);
    });

    testWidgets('whitespace-only is invalid', (tester) async {
      await _pumpScreen(tester);
      await tester.enterText(_field, '     ');
      await tester.pump();
      expect(find.text(_validationErrorText), findsOneWidget);
      expect(_enabled(tester), isFalse);
    });

    testWidgets('padded 2-char name is invalid, padded 3-char valid', (
      tester,
    ) async {
      await _pumpScreen(tester);
      await tester.enterText(_field, '  ab  ');
      await tester.pump();
      expect(_enabled(tester), isFalse);
      await tester.enterText(_field, '  abc  ');
      await tester.pump();
      expect(_enabled(tester), isTrue);
    });
  });

  testWidgets('chip tap fills field, enables button, keeps focus', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.tap(find.text('Kids'));
    await tester.pump();
    expect(tester.widget<TextField>(_field).controller!.text, 'Kids');
    expect(_enabled(tester), isTrue);
    expect(tester.widget<TextField>(_field).focusNode!.hasFocus, isTrue);
  });

  testWidgets('chip tap clears an existing validation error', (tester) async {
    await _pumpScreen(tester);
    await tester.enterText(_field, 'ab');
    await tester.pump();
    expect(find.text(_validationErrorText), findsOneWidget);
    await tester.tap(find.text('Kids'));
    await tester.pump();
    expect(find.text(_validationErrorText), findsNothing);
  });

  testWidgets('Create button exposes button semantics with enabled state', (
    tester,
  ) async {
    await _pumpScreen(tester);
    Semantics createSemantics() => tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.enabled != null,
      ),
    );
    expect(createSemantics().properties.button, isTrue);
    expect(createSemantics().properties.enabled, isFalse);
    await tester.enterText(_field, 'Household');
    await tester.pump();
    expect(createSemantics().properties.enabled, isTrue);
  });

  testWidgets('tapping Create calls createSpace with trimmed name', (
    tester,
  ) async {
    final n = await _pumpScreen(tester);
    await tester.enterText(_field, '  Household  ');
    await tester.pump();
    await tester.tap(_createText);
    await tester.pump();
    expect(n.createSpaceCallCount, 1);
    expect(n.lastCreatedName, 'Household');
  });

  testWidgets('loading shows spinner and button is not tappable', (
    tester,
  ) async {
    await _pumpScreen(tester, pending: true);
    await tester.enterText(_field, 'Household');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_createText, findsNothing);
    expect(_enabled(tester), isFalse);
  });

  testWidgets('failure shows inline message', (tester) async {
    await _pumpScreen(tester, initialError: const NetworkFailure());
    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('success navigates to task list', (tester) async {
    final n = _FakeCreateSpaceNotifier(spaceOnCreate: _space(id: 'space-99'));
    await _pumpCreateSpaceScreenWithRouter(tester, notifier: n);
    await tester.enterText(_field, 'Household');
    await tester.pump();
    await tester.tap(_createText);
    await tester.pumpAndSettle();
    expect(find.text('Task List Placeholder'), findsOneWidget);
    expect(n.createSpaceCallCount, 1);
  });

  testWidgets('Cancel pops when possible', (tester) async {
    final n = _FakeCreateSpaceNotifier();
    final router = await _pumpCreateSpaceScreenWithRouter(tester, notifier: n);
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    router.push(AppRoutes.createSpace);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Home Placeholder'), findsOneWidget);
    expect(find.text('New space'), findsNothing);
  });

  testWidgets('Cancel goes home when nothing to pop', (tester) async {
    final n = _FakeCreateSpaceNotifier();
    await _pumpCreateSpaceScreenWithRouter(tester, notifier: n);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Home Placeholder'), findsOneWidget);
  });

  testWidgets('dark mode renders without exceptions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_user)),
          createSpaceProvider.overrideWith(() => _FakeCreateSpaceNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const CreateSpaceScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('New space'), findsOneWidget);
  });
}
