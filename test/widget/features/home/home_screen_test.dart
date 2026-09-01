// Widget tests for HomeScreen (S-02). Controls userSpacesProvider directly
// — the cleanest override point for a screen-level test, since HomeScreen
// only ever reads that provider (never authStateProvider,
// firestoreProvider, or homeRepositoryProvider directly) — via a plain
// Stream override, mirroring settings_screen_test.dart's
// single-pump-after-pumpWidget pattern for stream-backed providers. Never
// touches real Firebase or Firestore.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';
import 'package:shared_tasks/features/home/domain/entities/member_avatar.dart';
import 'package:shared_tasks/features/home/presentation/home_screen.dart';
import 'package:shared_tasks/features/home/presentation/providers/home_provider.dart';

class _MockHttpClient extends Mock implements HttpClient {}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {}

class _MockHttpClientResponse extends Mock implements HttpClientResponse {}

class _MockHttpHeaders extends Mock implements HttpHeaders {}

/// Serves every NetworkImage request a minimal valid 1x1 transparent PNG so
/// a MemberAvatar with a non-null photoUrl doesn't attempt a real (sandboxed,
/// nonexistent) network load. Copied from settings_screen_test.dart's
/// established pattern.
class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
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

HomeSpace _privateSpace({
  String id = 'space-private',
  String name = 'My Chores',
  int openTaskCount = 0,
}) {
  return HomeSpace(
    id: id,
    name: name,
    memberUids: const ['uid-1'],
    openTaskCount: openTaskCount,
    updatedAt: DateTime(2026, 1, 1),
    memberAvatars: const [],
  );
}

HomeSpace _sharedSpace({
  String id = 'space-shared',
  String name = 'Household',
  int openTaskCount = 2,
  List<MemberAvatar> memberAvatars = const [
    MemberAvatar(uid: 'uid-1', displayName: 'Ada'),
    MemberAvatar(
      uid: 'uid-2',
      displayName: 'Bea',
      photoUrl: 'https://example.com/bea.jpg',
    ),
  ],
}) {
  return HomeSpace(
    id: id,
    name: name,
    memberUids: const ['uid-1', 'uid-2'],
    openTaskCount: openTaskCount,
    updatedAt: DateTime(2026, 1, 1),
    memberAvatars: memberAvatars,
  );
}

/// Pumps [HomeScreen] with [userSpacesProvider] overridden to [stream].
Future<void> _pumpHomeScreen(
  WidgetTester tester, {
  required Stream<List<HomeSpace>> stream,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userSpacesProvider.overrideWith((ref) => stream)],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pump();
}

/// Locates the `Card` that contains [spaceName] — used to scope
/// icon/avatar assertions to one specific space's card.
Finder _cardFor(String spaceName) =>
    find.ancestor(of: find.text(spaceName), matching: find.byType(Card));

/// A minimal real GoRouter harness (home → settings / create space) for
/// testing that the app bar settings icon and FAB navigate without
/// throwing, matching the pattern in test/widget/core/app_router_test.dart.
GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) =>
            const Scaffold(body: Text('Settings Placeholder')),
      ),
      GoRoute(
        path: AppRoutes.createSpace,
        builder: (context, state) =>
            const Scaffold(body: Text('Create Space Placeholder')),
      ),
    ],
  );
}

Future<GoRouter> _pumpHomeScreenWithRouter(
  WidgetTester tester, {
  required Stream<List<HomeSpace>> stream,
}) async {
  final router = _buildTestRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userSpacesProvider.overrideWith((ref) => stream)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return router;
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

  group('HomeScreen — loading state', () {
    testWidgets(
        'shows a CircularProgressIndicator and no card/empty-state content '
        'while userSpacesProvider has not yet emitted', (tester) async {
      await _pumpHomeScreen(
        tester,
        stream: const Stream<List<HomeSpace>>.empty(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('No spaces yet'), findsNothing);
    });
  });

  group('HomeScreen — error state', () {
    testWidgets(
        'shows the inline error text and no dialog/snackbar when the '
        'stream emits an error', (tester) async {
      await _pumpHomeScreen(
        tester,
        stream: Stream<List<HomeSpace>>.error(Exception('firestore boom')),
      );

      expect(
        find.text('Something went wrong loading your spaces.'),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('HomeScreen — empty state', () {
    testWidgets(
        'shows "No spaces yet" and the create-your-first-space prompt when '
        'the list is empty', (tester) async {
      await _pumpHomeScreen(tester, stream: Stream.value(const []));

      expect(find.text('No spaces yet'), findsOneWidget);
      expect(
        find.text('Create your first space to get started'),
        findsOneWidget,
      );
      expect(find.byType(Card), findsNothing);
    });
  });

  group('HomeScreen — populated state, ordering', () {
    testWidgets(
        'renders every space name in the same order the list was given, '
        'without re-sorting', (tester) async {
      final zeta = _privateSpace(id: 's1', name: 'Zeta Space');
      final alpha = _privateSpace(id: 's2', name: 'Alpha Space');
      await _pumpHomeScreen(tester, stream: Stream.value([zeta, alpha]));

      expect(find.text('Zeta Space'), findsOneWidget);
      expect(find.text('Alpha Space'), findsOneWidget);

      final zetaDy = tester.getTopLeft(find.text('Zeta Space')).dy;
      final alphaDy = tester.getTopLeft(find.text('Alpha Space')).dy;
      expect(
        zetaDy,
        lessThan(alphaDy),
        reason: 'Zeta was first in the emitted list, so it must render '
            'above Alpha — HomeScreen must not re-sort.',
      );
    });
  });

  group('HomeScreen — private space card', () {
    testWidgets(
        'shows the name, lock icon, task count, and no avatar row',
        (tester) async {
      final space = _privateSpace(name: 'My Chores', openTaskCount: 3);
      await _pumpHomeScreen(tester, stream: Stream.value([space]));

      final card = _cardFor('My Chores');
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.people)),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.text('3 open tasks')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(CircleAvatar)),
        findsNothing,
      );
    });
  });

  group('HomeScreen — shared space card', () {
    testWidgets(
        'shows the people icon and one CircleAvatar per member avatar',
        (tester) async {
      final space = _sharedSpace(name: 'Household');
      await _pumpHomeScreen(tester, stream: Stream.value([space]));

      final card = _cardFor('Household');
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.people)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.byType(CircleAvatar)),
        findsNWidgets(space.memberAvatars.length),
      );
    });

    testWidgets('a member avatar with photoUrl == null shows its initial '
        'letter', (tester) async {
      final space = _sharedSpace(
        name: 'Household',
        memberAvatars: const [
          MemberAvatar(uid: 'uid-1', displayName: 'Ada'),
        ],
      );
      await _pumpHomeScreen(tester, stream: Stream.value([space]));

      final card = _cardFor('Household');
      final avatar = tester.widget<CircleAvatar>(
        find.descendant(of: card, matching: find.byType(CircleAvatar)),
      );
      expect(avatar.backgroundImage, isNull);
      expect(
        find.descendant(of: card, matching: find.text('A')),
        findsOneWidget,
      );
    });

    testWidgets('a member avatar with a non-null photoUrl uses a '
        'NetworkImage background', (tester) async {
      final space = _sharedSpace(
        name: 'Household',
        memberAvatars: const [
          MemberAvatar(
            uid: 'uid-2',
            displayName: 'Bea',
            photoUrl: 'https://example.com/bea.jpg',
          ),
        ],
      );
      await _pumpHomeScreen(tester, stream: Stream.value([space]));

      final card = _cardFor('Household');
      final avatar = tester.widget<CircleAvatar>(
        find.descendant(of: card, matching: find.byType(CircleAvatar)),
      );
      expect(avatar.backgroundImage, isA<NetworkImage>());
      expect(avatar.child, isNull);
    });
  });

  group('HomeScreen — task count text', () {
    testWidgets('0 open tasks renders "No open tasks"', (tester) async {
      final space = _privateSpace(name: 'Space A', openTaskCount: 0);
      await _pumpHomeScreen(tester, stream: Stream.value([space]));

      expect(find.text('No open tasks'), findsOneWidget);
    });

    testWidgets('1 open task renders the singular "1 open task"',
        (tester) async {
      final space = _privateSpace(name: 'Space A', openTaskCount: 1);
      await _pumpHomeScreen(tester, stream: Stream.value([space]));

      expect(find.text('1 open task'), findsOneWidget);
      expect(find.text('1 open tasks'), findsNothing);
    });

    testWidgets('N (>1) open tasks renders the plural "N open tasks"',
        (tester) async {
      final space = _privateSpace(name: 'Space A', openTaskCount: 5);
      await _pumpHomeScreen(tester, stream: Stream.value([space]));

      expect(find.text('5 open tasks'), findsOneWidget);
    });
  });

  group('HomeScreen — app bar and FAB', () {
    testWidgets('the settings IconButton is present', (tester) async {
      await _pumpHomeScreen(tester, stream: Stream.value(const []));

      expect(
        find.widgetWithIcon(IconButton, Icons.settings),
        findsOneWidget,
      );
    });

    testWidgets('tapping the settings icon navigates to the settings route '
        'without throwing', (tester) async {
      await _pumpHomeScreenWithRouter(
        tester,
        stream: Stream.value(const []),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings Placeholder'), findsOneWidget);
    });

    testWidgets('the FAB is present with Icons.add', (tester) async {
      await _pumpHomeScreen(tester, stream: Stream.value(const []));

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('tapping the FAB navigates to the create-space route '
        'without throwing', (tester) async {
      await _pumpHomeScreenWithRouter(
        tester,
        stream: Stream.value(const []),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create Space Placeholder'), findsOneWidget);
    });
  });
}
