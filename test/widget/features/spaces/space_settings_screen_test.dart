// Widget tests for SpaceSettingsScreen (S-06, redesigned in issue #58).
// Controls spaceProvider(spaceId), spaceMembersProvider(spaceId),
// authStateProvider and regenerateInviteProvider (via a fake
// AutoDisposeAsyncNotifier, mirroring create_space_screen_test.dart's
// pattern) so every state can be driven without touching real Firebase or
// Firestore. share_plus is exercised through a mocked MethodChannel only.
//
// Every pumped MaterialApp sets `theme: AppTheme.light` — these widgets
// read AppColors.of(context), which null-asserts without the extension.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';
import 'package:shared_tasks/features/invite/presentation/providers/invite_provider.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/space_settings_screen.dart';
import 'package:shared_tasks/features/spaces/presentation/widgets/invite_link_box.dart';
import 'package:shared_tasks/features/spaces/presentation/widgets/member_row.dart';

const _spaceId = 'space-1';

const _owner = AppUser(
  id: 'uid-1',
  displayName: 'Ada',
  email: 'ada@example.com',
);
const _nonOwner = AppUser(
  id: 'uid-2',
  displayName: 'Bea',
  email: 'bea@example.com',
);

const _snackBarText = 'New invite link generated — the old one no longer works';

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
/// - [initialError] makes the initial state `AsyncError` (as if a previous
///   attempt had already failed).
/// - [pending] makes `build()` return a Future that never resolves, so the
///   initial state stays `AsyncLoading`.
/// - [initialInvite] sets the initial `AsyncData` value (defaults to `null`,
///   the pristine "no attempt yet" state).
/// - [resultInvite], when non-null, is what [regenerate] pushes into state —
///   this is what drives the success-SnackBar path.
class _FakeRegenerateInviteController extends RegenerateInviteController {
  _FakeRegenerateInviteController({
    this.initialInvite,
    this.initialError,
    this.pending = false,
    this.resultInvite,
  });

  final Invite? initialInvite;
  final Object? initialError;
  final bool pending;
  final Invite? resultInvite;

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
    if (resultInvite != null) {
      state = AsyncData<Invite?>(resultInvite);
    }
  }

  /// Drops back to the pristine `AsyncData(null)` that `build()` returns —
  /// what an `invalidate`/`refresh` of this autoDispose provider looks like
  /// while the screen is still mounted. Setting an equal value wouldn't
  /// notify, so this is only a real transition after a successful
  /// regenerate has moved the state elsewhere.
  void resetToPristine() => state = const AsyncData<Invite?>(null);
}

/// Pumps [SpaceSettingsScreen] with every provider it reads overridden.
Future<_FakeRegenerateInviteController> _pumpScreen(
  WidgetTester tester, {
  Space? space,
  Stream<Space?>? spaceStream,
  List<MemberAvatar> members = const [],
  bool membersPending = false,
  Object? membersError,
  AppUser? user = _owner,
  Object? regenerateInitialError,
  bool regeneratePending = false,
  Invite? regenerateInitialInvite,
  Invite? regenerateResult,
  bool dark = false,
}) async {
  final controller = _FakeRegenerateInviteController(
    initialInvite: regenerateInitialInvite,
    initialError: regenerateInitialError,
    pending: regeneratePending,
    resultInvite: regenerateResult,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spaceProvider.overrideWith(
          (ref, id) => spaceStream ?? Stream.value(space),
        ),
        spaceMembersProvider.overrideWith((ref, id) {
          if (membersPending) return Completer<List<MemberAvatar>>().future;
          if (membersError != null) {
            return Future<List<MemberAvatar>>.error(membersError);
          }
          return Future<List<MemberAvatar>>.value(members);
        }),
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        regenerateInviteProvider.overrideWith(() => controller),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const SpaceSettingsScreen(spaceId: _spaceId),
      ),
    ),
  );
  await tester.pump();
  // A second pump lets spaceMembersProvider's FutureProvider — first
  // watched only once spaceProvider's stream has resolved to AsyncData —
  // resolve in turn, a second dependent microtask hop.
  await tester.pump();

  return controller;
}

void main() {
  group('SpaceSettingsScreen — top-level states', () {
    testWidgets('shows a spinner while the space is loading', (tester) async {
      await _pumpScreen(tester, spaceStream: const Stream<Space?>.empty());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The screen's content isn't rendered yet, but the back link is —
      // it now sits outside spaceState.when() so no state is a dead end,
      // and with no space loaded its label is the 'Space settings'
      // fallback.
      expect(find.text('Send invite'), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('shows an inline message when the space stream errors', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        spaceStream: Stream<Space?>.error(Exception('firestore boom')),
      );

      expect(
        find.text('Something went wrong loading this space.'),
        findsOneWidget,
      );
      // Reachable states must still offer a way out — the back link is
      // rendered outside spaceState.when().
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('shows a not-found message when the space is null', (
      tester,
    ) async {
      await _pumpScreen(tester, space: null);

      expect(find.text('This space has been deleted.'), findsOneWidget);
    });

    testWidgets('renders in dark mode without throwing', (tester) async {
      await _pumpScreen(
        tester,
        dark: true,
        space: _space(memberUids: const ['uid-1']),
        members: const [MemberAvatar(uid: 'uid-1', displayName: 'Ada')],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Space settings'), findsOneWidget);
      expect(find.text('Send invite'), findsOneWidget);
    });
  });

  group('SpaceSettingsScreen — header', () {
    testWidgets('back link shows the space name and a back arrow', (
      tester,
    ) async {
      await _pumpScreen(tester, space: _space(name: 'Household'));

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      // Back link label + subtitle both render the space name.
      expect(find.text('Household'), findsNWidgets(2));
    });

    testWidgets('renders the "Space settings" title and the space-name '
        'subtitle', (tester) async {
      await _pumpScreen(tester, space: _space(name: 'Household'));

      expect(find.text('Space settings'), findsOneWidget);
      expect(find.text('Household'), findsNWidgets(2));
    });

    testWidgets('omits the subtitle when the space name is empty, so it '
        'cannot duplicate the title', (tester) async {
      await _pumpScreen(tester, space: _space(name: ''));

      // The back link falls back to "Space settings"; the title is the
      // other one. If the subtitle also rendered there would be three.
      expect(find.text('Space settings'), findsNWidgets(2));
    });
  });

  group('SpaceSettingsScreen — section labels', () {
    testWidgets('renders the uppercase MEMBERS and INVITE LINK labels', (
      tester,
    ) async {
      await _pumpScreen(tester, space: _space());

      expect(find.text('MEMBERS'), findsOneWidget);
      expect(find.text('INVITE LINK'), findsOneWidget);
      expect(find.text('Members'), findsNothing);
      expect(find.text('Invite link'), findsNothing);
    });
  });

  group('SpaceSettingsScreen — members section', () {
    testWidgets('renders one MemberRow per member, with isOwner true only '
        'for the space owner', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1', memberUids: const ['uid-1', 'uid-2']),
        members: const [
          MemberAvatar(uid: 'uid-1', displayName: 'Ada'),
          MemberAvatar(uid: 'uid-2', displayName: 'Bea'),
        ],
      );

      final rows = tester
          .widgetList<MemberRow>(find.byType(MemberRow))
          .toList();
      expect(rows, hasLength(2));
      expect(rows[0].member.uid, 'uid-1');
      expect(rows[0].isOwner, isTrue);
      expect(rows[1].member.uid, 'uid-2');
      expect(rows[1].isOwner, isFalse);

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bea'), findsOneWidget);
      expect(find.text('owner'), findsOneWidget);
    });

    testWidgets('shows a spinner while the member list is loading', (
      tester,
    ) async {
      await _pumpScreen(tester, space: _space(), membersPending: true);

      expect(find.byType(MemberRow), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The rest of the screen still renders — members are enrichment.
      expect(find.text('INVITE LINK'), findsOneWidget);
    });

    testWidgets('renders nothing, without throwing, when the member list '
        'fails', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(),
        membersError: const NetworkFailure(),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MemberRow), findsNothing);
      expect(find.text('INVITE LINK'), findsOneWidget);
    });
  });

  group('SpaceSettingsScreen — invite link', () {
    testWidgets('shows the https shareableLink, not a sharedtasks:// URI', (
      tester,
    ) async {
      final space = _space(inviteToken: 'tok-xyz');
      await _pumpScreen(tester, space: space);

      final invite = Invite(
        spaceId: space.id,
        token: space.inviteToken,
        expiresAt: space.inviteExpiresAt,
      );

      final box = tester.widget<InviteLinkBox>(find.byType(InviteLinkBox));
      expect(box.link, invite.shareableLink);
      expect(box.link, startsWith('https://'));
      expect(box.link, contains('tok-xyz'));
      expect(find.text(invite.shareableLink), findsOneWidget);
      expect(find.text('sharedtasks://join/tok-xyz'), findsNothing);
    });
  });

  group('SpaceSettingsScreen — Send invite button', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('is shown to the owner', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
      );

      expect(find.text('Send invite'), findsOneWidget);
    });

    testWidgets('is shown to a non-owner too', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _nonOwner,
      );

      expect(find.text('Send invite'), findsOneWidget);
    });

    // Regression test for the real iOS bug found during #31's manual
    // testing: share_plus's native iOS side silently does nothing if
    // `sharePositionOrigin` is omitted, because
    // UIActivityViewController.popoverPresentationController is non-nil
    // even on iPhone on current iOS. The button is wrapped in a Builder so
    // its onPressed can resolve its own RenderBox and pass a real,
    // non-empty origin rect.
    testWidgets('tapping it invokes the platform channel with a non-empty '
        'sharePositionOrigin', (tester) async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            capturedCall = call;
            return 'dev.fluttercommunity.plus/share/success';
          });

      await _pumpScreen(tester, space: _space(inviteToken: 'tok-xyz'));

      await tester.tap(find.text('Send invite'));
      await tester.pumpAndSettle();

      expect(capturedCall, isNotNull);
      expect(capturedCall!.method, 'share');
      final args = capturedCall!.arguments as Map;
      expect(args['originWidth'], greaterThan(0));
      expect(args['originHeight'], greaterThan(0));
    });
  });

  group('SpaceSettingsScreen — Regenerate control, owner gate', () {
    testWidgets('IS shown when the signed-in uid matches ownerUid', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
      );

      expect(find.text('Regenerate link'), findsOneWidget);
    });

    testWidgets('is NOT shown when the signed-in uid does not match '
        'ownerUid', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _nonOwner,
      );

      expect(find.text('Regenerate link'), findsNothing);
    });

    testWidgets('is NOT shown when there is no signed-in user', (tester) async {
      await _pumpScreen(tester, space: _space(ownerUid: 'uid-1'), user: null);

      expect(find.text('Regenerate link'), findsNothing);
    });
  });

  group('SpaceSettingsScreen — Regenerate control, behavior', () {
    testWidgets('tapping Regenerate calls the controller with the spaceId', (
      tester,
    ) async {
      final controller = await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
      );

      await tester.tap(find.text('Regenerate link'));
      await tester.pump();

      expect(controller.regenerateCallCount, 1);
      expect(controller.lastSpaceId, _spaceId);
    });

    testWidgets('shows a spinner instead of the label, and is not tappable, '
        'while regenerating', (tester) async {
      final controller = await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
        regeneratePending: true,
      );

      expect(find.text('Regenerate link'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();
      expect(controller.regenerateCallCount, 0);
    });

    testWidgets("shows the AppFailure's own message inline on error", (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
        regenerateInitialError: const NetworkFailure(),
      );

      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets('falls back to a generic message for a non-AppFailure error', (
      tester,
    ) async {
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

  group('SpaceSettingsScreen — regenerate success SnackBar', () {
    final newInvite = Invite(
      spaceId: _spaceId,
      token: 'tok-new',
      expiresAt: DateTime(2028, 1, 1),
    );

    testWidgets('does NOT fire on first render while the state is pristine '
        'null', (tester) async {
      await _pumpScreen(tester, space: _space(ownerUid: 'uid-1'));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(_snackBarText), findsNothing);
    });

    testWidgets('does NOT fire when the provider drops back to a null value '
        'while the screen is still mounted', (tester) async {
      // The case the `valueOrNull == null` guard actually exists for.
      // Riverpod never calls a listener on first build, so the pristine
      // render is covered by Riverpod itself, not by the guard — only a
      // real transition back to AsyncData(null) exercises it.
      final controller = await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        regenerateResult: newInvite,
      );

      await tester.tap(find.text('Regenerate link'));
      await tester.pump();
      expect(find.text(_snackBarText), findsOneWidget);

      // Clear the first SnackBar deterministically, so any SnackBar still
      // present after the transition below can only be a new one.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      controller.resetToPristine();
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('does NOT fire on an error state', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        regenerateInitialError: const NetworkFailure(),
      );

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('fires once the provider resolves to a non-null Invite', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _owner,
        regenerateResult: newInvite,
      );

      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('Regenerate link'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_snackBarText), findsOneWidget);
    });
  });
}
