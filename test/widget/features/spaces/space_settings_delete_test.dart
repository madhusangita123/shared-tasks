// Widget tests for SpaceSettingsScreen's owner-only "Delete space" control
// and its confirmation dialog — issue #64.
//
// Kept separate from space_settings_screen_test.dart (which covers the
// screen's states, header, members, invite link and Regenerate control)
// because this flow needs two things that file's harness doesn't have: an
// openTaskCountProvider override, and a real GoRouter — the screen does
// `context.go(AppRoutes.home)` on a successful delete, which throws under a
// plain MaterialApp.
//
// deleteSpaceProvider is driven by a fake subclass of the real
// DeleteSpaceController, so its state transitions (loading, error) are the
// ones the screen actually renders. The controller's own logic — including
// the offline guard — is tested against the real class in
// delete_space_provider_test.dart.
//
// Never touches real Firebase.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/invite/presentation/providers/invite_provider.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/space_settings_screen.dart';

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

Space _space({String name = 'Household', String ownerUid = 'uid-1'}) {
  return Space(
    id: _spaceId,
    name: name,
    ownerUid: ownerUid,
    memberUids: const ['uid-1'],
    inviteToken: 'tok-abc',
    inviteExpiresAt: DateTime(2027, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

/// A controllable stand-in for [DeleteSpaceController], mirroring
/// space_settings_screen_test.dart's `_FakeRegenerateInviteController`.
///
/// [resultFailure] is what [deleteSpace] returns (and pushes into state);
/// `null` means success. [pending] keeps the delete in flight forever so the
/// button's loading state can be asserted.
class _FakeDeleteSpaceController extends DeleteSpaceController {
  _FakeDeleteSpaceController({this.resultFailure, this.pending = false});

  final AppFailure? resultFailure;
  final bool pending;

  int callCount = 0;
  String? lastSpaceId;

  @override
  Future<AppFailure?> deleteSpace(String spaceId) async {
    callCount++;
    lastSpaceId = spaceId;
    if (pending) {
      state = const AsyncLoading();
      return Completer<AppFailure?>().future;
    }
    final failure = resultFailure;
    if (failure != null) {
      state = AsyncError<void>(failure, StackTrace.current);
      return failure;
    }
    state = const AsyncData(null);
    return null;
  }
}

/// Pumps [SpaceSettingsScreen] inside a real [GoRouter] (so a successful
/// delete's `context.go(AppRoutes.home)` resolves to a real route), with
/// every provider it reads overridden.
///
/// [openTaskCount] of `null` combined with [countFails] `true` drives the
/// count-fetch failure path; otherwise [openTaskCount] is the resolved
/// count, and `null` with [countFails] `false` is never used.
Future<_FakeDeleteSpaceController> _pumpScreen(
  WidgetTester tester, {
  Space? space,
  AppUser? user = _owner,
  int openTaskCount = 0,
  bool countFails = false,
  bool countPending = false,
  AppFailure? deleteFailure,
  bool deletePending = false,
}) async {
  final controller = _FakeDeleteSpaceController(
    resultFailure: deleteFailure,
    pending: deletePending,
  );

  final router = GoRouter(
    initialLocation: AppRoutes.spaceSettingsPath(_spaceId),
    routes: [
      GoRoute(
        path: AppRoutes.spaceSettings,
        builder: (context, state) =>
            SpaceSettingsScreen(spaceId: state.pathParameters['spaceId']!),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('HOME STUB'))),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spaceProvider.overrideWith((ref, id) => Stream.value(space)),
        spaceMembersProvider.overrideWith(
          (ref, id) => Future<List<MemberAvatar>>.value(const []),
        ),
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        openTaskCountProvider.overrideWith((ref, id) {
          if (countPending) return Completer<int>().future;
          if (countFails) return Future<int>.error(const NetworkFailure());
          return Future<int>.value(openTaskCount);
        }),
        deleteSpaceProvider.overrideWith(() => controller),
        // Left at its real implementation elsewhere; overridden here only
        // so the screen's regenerate controls don't reach real Firestore.
        regenerateInviteProvider.overrideWith(
          _NoopRegenerateInviteController.new,
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();

  return controller;
}

class _NoopRegenerateInviteController extends RegenerateInviteController {
  @override
  Future<void> regenerate(String spaceId) async {}
}

void main() {
  group('Delete space button — owner gate', () {
    testWidgets('IS shown when the signed-in uid matches ownerUid', (
      tester,
    ) async {
      await _pumpScreen(tester, space: _space(ownerUid: 'uid-1'));

      expect(find.text('Delete space'), findsOneWidget);
    });

    testWidgets('is NOT shown to a non-owner member', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(ownerUid: 'uid-1'),
        user: _nonOwner,
      );

      expect(find.text('Delete space'), findsNothing);
    });

    testWidgets('is NOT shown when there is no signed-in user', (tester) async {
      await _pumpScreen(tester, space: _space(ownerUid: 'uid-1'), user: null);

      expect(find.text('Delete space'), findsNothing);
    });
  });

  group('Delete space button — states', () {
    testWidgets('shows a spinner instead of its label, and is not tappable, '
        'while a delete is in flight', (tester) async {
      final controller = await _pumpScreen(
        tester,
        space: _space(),
        deletePending: true,
      );

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));

      // Explicit durations rather than pumpAndSettle for the rest of this
      // test: the delete never completes (deletePending), so the in-flight
      // CircularProgressIndicator animates forever and pumpAndSettle would
      // time out. 500ms is comfortably past a dialog route transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.callCount, 1);
      expect(find.text('Delete space'), findsNothing);
      // Baseline: the confirmed dialog has finished popping, so a dialog
      // appearing after the next tap can only be a NEW one.
      expect(find.byType(AlertDialog), findsNothing);

      // A second tap on the in-flight button must not re-enter
      // _confirmAndDelete. Asserting callCount alone would NOT catch a
      // missing guard: the controller is only called once a dialog is
      // confirmed, so a freshly re-opened (unconfirmed) dialog leaves
      // callCount at 1 and the test passes while the guard is gone. The
      // observable effect of losing the guard is a second AlertDialog.
      await tester.tap(find.byType(CircularProgressIndicator).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.callCount, 1);
    });
  });

  group('Delete space dialog — copy', () {
    testWidgets('tapping Delete space opens the confirmation dialog', (
      tester,
    ) async {
      await _pumpScreen(tester, space: _space());

      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete space?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('names the space and pluralises a count of 3', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(name: 'Household'),
        openTaskCount: 3,
      );

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '"Household" has 3 open tasks. This deletes the space and all of '
          'its tasks for everyone in it. This cannot be undone.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses the singular "1 open task" for a count of 1', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        space: _space(name: 'Household'),
        openTaskCount: 1,
      );

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '"Household" has 1 open task. This deletes the space and all of '
          'its tasks for everyone in it. This cannot be undone.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a count of 0 uses the count-free copy and never says '
        '"0 open tasks"', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(name: 'Household'),
        openTaskCount: 0,
      );

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This deletes "Household" and all of its tasks for everyone in '
          'it. This cannot be undone.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('0 open'), findsNothing);
      expect(find.textContaining('has 0'), findsNothing);
    });

    testWidgets('falls back to "this space" when the space has no name', (
      tester,
    ) async {
      await _pumpScreen(tester, space: _space(name: ''), openTaskCount: 2);

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'this space has 2 open tasks. This deletes the space and all of '
          'its tasks for everyone in it. This cannot be undone.',
        ),
        findsOneWidget,
      );
    });

    // The important one: a count the app could not fetch must never stand
    // between the owner and a delete they asked for. The dialog still
    // opens, with count-free copy, the error is never surfaced, and the
    // delete still goes through.
    testWidgets('a FAILED count still opens the dialog with count-free copy '
        'and still allows the delete', (tester) async {
      final controller = await _pumpScreen(
        tester,
        space: _space(name: 'Household'),
        countFails: true,
      );

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(
          'This deletes "Household" and all of its tasks for everyone in '
          'it. This cannot be undone.',
        ),
        findsOneWidget,
      );
      // The count failure itself is deliberately invisible.
      expect(find.text('No internet connection'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(controller.callCount, 1);
    });
  });

  group('Delete space dialog — actions', () {
    testWidgets('Cancel dismisses the dialog without deleting', (tester) async {
      final controller = await _pumpScreen(tester, space: _space());

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.callCount, 0);
      // Still on settings, not navigated anywhere.
      expect(find.text('HOME STUB'), findsNothing);
    });

    testWidgets('dismissing the dialog by tapping the barrier does not '
        'delete', (tester) async {
      final controller = await _pumpScreen(tester, space: _space());

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();
      // Top-left corner is outside the AlertDialog — the barrier.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.callCount, 0);
    });

    testWidgets('Delete calls the controller exactly once with the space id, '
        'and on success navigates Home', (tester) async {
      final controller = await _pumpScreen(tester, space: _space());

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(controller.callCount, 1);
      expect(controller.lastSpaceId, _spaceId);
      // go, not pop: the task list this screen was pushed from is built
      // around a space that no longer exists.
      expect(find.text('HOME STUB'), findsOneWidget);
      expect(find.text('Delete space'), findsNothing);
    });

    testWidgets("on failure stays on the screen and renders the failure's "
        'own message inline', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(),
        deleteFailure: const PermissionFailure(),
      );

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('You do not have permission'), findsOneWidget);
      expect(find.text('HOME STUB'), findsNothing);
      expect(find.text('Delete space'), findsOneWidget);
    });

    testWidgets("renders the Delete control's own error, not the "
        'Regenerate control\'s generic fallback', (tester) async {
      await _pumpScreen(
        tester,
        space: _space(),
        deleteFailure: const AuthFailure('You must be signed in.'),
      );

      await tester.tap(find.text('Delete space'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('You must be signed in.'), findsOneWidget);
      expect(
        find.text('Could not regenerate the link. Try again.'),
        findsNothing,
      );
      expect(
        find.text('Could not delete this space. Try again.'),
        findsNothing,
      );
    });
  });
}
