// Widget tests for SpaceSettingsScreen (S-06, issue #31). Controls
// spaceProvider(spaceId), spaceMembersProvider(spaceId), authStateProvider,
// and regenerateInviteProvider (via a fake AutoDisposeAsyncNotifier,
// mirroring create_space_screen_test.dart's _FakeCreateSpaceNotifier
// pattern) so every state can be driven without touching real Firebase or
// Firestore. Copies home_screen_test.dart's _FakeHttpOverrides setup for
// member avatars that render a photo via NetworkImage.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';
import 'package:shared_tasks/features/invite/presentation/providers/invite_provider.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/space_settings_screen.dart';

const _spaceId = 'space-1';

const _owner = AppUser(id: 'uid-1', displayName: 'Ada', email: 'ada@example.com');
const _nonOwner =
    AppUser(id: 'uid-2', displayName: 'Bea', email: 'bea@example.com');

class _MockHttpClient extends Mock implements HttpClient {}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {}

class _MockHttpClientResponse extends Mock implements HttpClientResponse {}

class _MockHttpHeaders extends Mock implements HttpHeaders {}

/// Serves every NetworkImage request a minimal valid 1x1 transparent PNG so
/// a MemberAvatar with a non-null photoUrl doesn't attempt a real (sandboxed,
/// nonexistent) network load. Copied from home_screen_test.dart's
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

Space _space({
  String id = _spaceId,
  String name = 'Household',
  String ownerUid = 'uid-1',
  List<String> memberUids = const ['uid-1'],
  String inviteToken = 'tok-abc',
}) {
  return Space(
    id: id,
    name: name,
    ownerUid: ownerUid,
    memberUids: memberUids,
    inviteToken: inviteToken,
    inviteExpiresAt: DateTime(2027, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

/// A controllable stand-in for [RegenerateInviteController].
///
/// - [initialError] makes the notifier's initial state `AsyncError` (as if
///   a previous regenerate attempt had already failed).
/// - [pending] makes `build()` return a `Future` that never resolves during
///   the test, so the initial state stays `AsyncLoading`.
/// - [initialInvite] sets the initial `AsyncData` value directly (defaults
///   to `null`, the pristine "no attempt yet" state).
///
/// [regenerate] is overridden so tapping the button never reaches the real
/// repository/Cloud Function — it just records the call.
class _FakeRegenerateInviteController extends RegenerateInviteController {
  _FakeRegenerateInviteController({
    this.initialInvite,
    this.initialError,
    this.pending = false,
  });

  final Invite? initialInvite;
  final Object? initialError;
  final bool pending;

  int regenerateCallCount = 0;
  String? lastSpaceId;

  @override
  FutureOr<Invite?> build() {
    if (initialError != null) {
      throw initialError!;
    }
    if (pending) {
      return Completer<Invite?>().future;
    }
    return initialInvite;
  }

  @override
  Future<void> regenerate(String spaceId) async {
    regenerateCallCount++;
    lastSpaceId = spaceId;
  }
}

/// Pumps [SpaceSettingsScreen] with every provider it reads overridden.
Future<_FakeRegenerateInviteController> _pumpScreen(
  WidgetTester tester, {
  Space? space,
  Stream<Space?>? spaceStream,
  List<MemberAvatar> members = const [],
  AppUser? user = _owner,
  Object? regenerateInitialError,
  bool regeneratePending = false,
  Invite? regenerateInitialInvite,
}) async {
  final controller = _FakeRegenerateInviteController(
    initialInvite: regenerateInitialInvite,
    initialError: regenerateInitialError,
    pending: regeneratePending,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spaceProvider.overrideWith(
          (ref, id) => spaceStream ?? Stream.value(space),
        ),
        spaceMembersProvider.overrideWith((ref, id) async => members),
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        regenerateInviteProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(home: SpaceSettingsScreen(spaceId: _spaceId)),
    ),
  );
  await tester.pump();
  // A second pump lets spaceMembersProvider's FutureProvider — first
  // watched only once spaceProvider's stream has resolved to AsyncData —
  // resolve in turn, since that's a second, dependent microtask hop beyond
  // the first pump above.
  await tester.pump();

  return controller;
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

  group('SpaceSettingsScreen — AppBar title', () {
    testWidgets('shows "Space settings" while the space is loading',
        (tester) async {
      await _pumpScreen(
        tester,
        spaceStream: const Stream<Space?>.empty(),
      );

      expect(find.text('Space settings'), findsOneWidget);
    });

    testWidgets("shows the space's own name once loaded", (tester) async {
      await _pumpScreen(tester, space: _space(name: 'Household'));

      expect(find.text('Household'), findsOneWidget);
    });

    testWidgets('shows "Space settings" on error', (tester) async {
      await _pumpScreen(
        tester,
        spaceStream: Stream<Space?>.error(Exception('firestore boom')),
      );

      expect(find.text('Space settings'), findsOneWidget);
      expect(
        find.text('Something went wrong loading this space.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a not-found message when the space is null',
        (tester) async {
      await _pumpScreen(tester, space: null);

      expect(
        find.text('This space could not be found.'),
        findsOneWidget,
      );
    });
  });

  group('SpaceSettingsScreen — members section', () {
    testWidgets('renders each member name, with photo vs initial-letter '
        'avatars', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(memberUids: const ['uid-1', 'uid-2']),
        members: const [
          MemberAvatar(uid: 'uid-1', displayName: 'Ada'),
          MemberAvatar(
            uid: 'uid-2',
            displayName: 'Bea',
            photoUrl: 'https://example.com/bea.jpg',
          ),
        ],
      );

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bea'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNWidgets(2));

      final adaAvatar = tester.widget<CircleAvatar>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Ada'),
            matching: find.byType(Row),
          ),
          matching: find.byType(CircleAvatar),
        ),
      );
      expect(adaAvatar.backgroundImage, isNull);
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('Ada'), matching: find.byType(Row)),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );

      final beaAvatar = tester.widget<CircleAvatar>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Bea'),
            matching: find.byType(Row),
          ),
          matching: find.byType(CircleAvatar),
        ),
      );
      expect(beaAvatar.backgroundImage, isA<NetworkImage>());
      expect(beaAvatar.child, isNull);
    });
  });

  group('SpaceSettingsScreen — Share section', () {
    testWidgets('shows the invite link text matching Invite.shareableLink '
        'and a Share button', (tester) async {
      final space = _space(inviteToken: 'tok-xyz');
      await _pumpScreen(tester, space: space);

      final invite = Invite(
        spaceId: space.id,
        token: space.inviteToken,
        expiresAt: space.inviteExpiresAt,
      );

      expect(find.text(invite.shareableLink), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Share'), findsOneWidget);
    });
  });

  group('SpaceSettingsScreen — Share button, behavior', () {
    // Regression test for the real iOS bug found during #31's manual
    // testing: `share_plus`'s native iOS side silently does nothing (never
    // presents anything) if `sharePositionOrigin` is omitted, because
    // `UIActivityViewController.popoverPresentationController` is non-nil
    // even on iPhone on current iOS. The Share button is wrapped in a
    // `Builder` so its `onPressed` can resolve its own RenderBox and pass a
    // real, non-empty origin rect. Verified here by mocking share_plus's
    // MethodChannel directly and asserting the origin fields it received
    // are non-zero — a plain "did shareInviteLink get called" test
    // wouldn't catch a regression back to passing no origin at all.
    const channel = MethodChannel('dev.fluttercommunity.plus/share');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets(
      'tapping Share invokes the platform channel with a non-empty '
      'sharePositionOrigin',
      (tester) async {
        MethodCall? capturedCall;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              capturedCall = call;
              return 'dev.fluttercommunity.plus/share/success';
            });

        await _pumpScreen(tester, space: _space(inviteToken: 'tok-xyz'));

        await tester.tap(find.widgetWithText(AppButton, 'Share'));
        await tester.pumpAndSettle();

        expect(capturedCall, isNotNull);
        expect(capturedCall!.method, 'share');
        final args = capturedCall!.arguments as Map;
        expect(args['originWidth'], greaterThan(0));
        expect(args['originHeight'], greaterThan(0));
      },
    );
  });

  group('SpaceSettingsScreen — Regenerate control, owner gate', () {
    testWidgets('IS shown when the signed-in uid matches ownerUid',
        (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
      );

      expect(find.widgetWithText(AppButton, 'Regenerate link'), findsOneWidget);
    });

    testWidgets('is NOT shown when the signed-in uid does not match ownerUid',
        (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _nonOwner,
      );

      expect(find.widgetWithText(AppButton, 'Regenerate link'), findsNothing);
    });
  });

  group('SpaceSettingsScreen — Regenerate control, behavior', () {
    testWidgets('tapping Regenerate calls the controller with spaceId',
        (tester) async {
      final controller = await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
      );

      await tester.tap(find.widgetWithText(AppButton, 'Regenerate link'));
      await tester.pump();

      expect(controller.regenerateCallCount, 1);
      expect(controller.lastSpaceId, _spaceId);
    });

    testWidgets("the Regenerate AppButton's isLoading is true while state "
        'is AsyncLoading', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
        regeneratePending: true,
      );

      // Not find.widgetWithText — AppButton hides its label Text entirely
      // while isLoading (see app_button.dart), so the loading Regenerate
      // button has to be located positionally instead: Share renders first,
      // Regenerate (owner-only) second.
      final button = tester.widgetList<AppButton>(find.byType(AppButton)).last;
      expect(button.isLoading, isTrue);
    });

    testWidgets("shows the AppFailure's own message inline on error",
        (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
        regenerateInitialError: const NetworkFailure(),
      );

      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets('falls back to a generic message for a non-AppFailure '
        'error', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
        regenerateInitialError: Exception('boom'),
      );

      expect(
        find.text('Could not regenerate the link. Try again.'),
        findsOneWidget,
      );
    });
  });
}
