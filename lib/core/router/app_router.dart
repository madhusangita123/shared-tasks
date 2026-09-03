import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/router/deep_link_provider.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/auth/presentation/settings_screen.dart';
import 'package:shared_tasks/features/auth/presentation/sign_in_screen.dart';
import 'package:shared_tasks/features/home/presentation/home_screen.dart';
import 'package:shared_tasks/features/invite/presentation/join_space_screen.dart';
import 'package:shared_tasks/features/spaces/presentation/create_space_screen.dart';
import 'package:shared_tasks/features/spaces/presentation/space_settings_screen.dart';
import 'package:shared_tasks/features/tasks/presentation/task_list_screen.dart';

/// A bare [ChangeNotifier] whose only job is to be go_router's
/// `refreshListenable` — calling [refresh] tells [GoRouter] to re-run
/// `redirect` without needing a new [GoRouter] instance.
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// App-wide [GoRouter] configuration.
///
/// Route builders are placeholders until each feature screen lands (see
/// CLAUDE.md — Feature build order), except sign-in which is real.
///
/// A single [GoRouter] instance lives for as long as this provider does.
/// `redirect` reads the *current* auth state with `ref.read` at
/// navigation-time rather than `ref.watch`-ing it at build-time.
/// `ref.listen(authStateProvider, ...)` drives a [_RouterRefreshNotifier]
/// used as `refreshListenable`, so go_router re-runs `redirect` whenever
/// `authStateProvider` changes — without discarding and recreating the
/// router (which would otherwise reset navigation to `initialLocation` on
/// every auth transition). `ref.listen` is used instead of the deprecated
/// `authStateProvider.stream`.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(authStateProvider, (previous, next) => refreshNotifier.refresh());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.signIn,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // A sharedtasks://join/{token} deep link can arrive as a full
      // external URI (scheme, host, and all) rather than an app-relative
      // path — whichever mechanism actually delivers it: Flutter's own
      // built-in deep-link routing (enabled by default on both platforms,
      // forwarding the raw launch/intent URL straight into this router),
      // or app_links' own listening in deep_link_provider.dart. go_router's
      // routes are all app-relative paths, so a raw external URI has to be
      // normalized to one here, before route matching runs — otherwise it
      // fails with "GoException: no routes for location:
      // sharedtasks://join/...". Handling it in `redirect` (rather than
      // relying on exactly one delivery mechanism) means it doesn't matter
      // which one actually fires, on either platform, cold start or warm.
      if (state.uri.scheme == 'sharedtasks') {
        final token = extractJoinToken(state.uri);
        if (token != null) return AppRoutes.joinSpacePath(token);
      }

      final isAuthenticated = ref.read(authStateProvider).valueOrNull != null;
      final isOnSignIn = state.matchedLocation == AppRoutes.signIn;
      if (!isAuthenticated && !isOnSignIn) return AppRoutes.signIn;
      if (isAuthenticated && isOnSignIn) return AppRoutes.home;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createSpace,
        builder: (context, state) => const CreateSpaceScreen(),
      ),
      GoRoute(
        path: AppRoutes.taskList,
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return TaskListScreen(spaceId: spaceId);
        },
      ),
      GoRoute(
        path: AppRoutes.spaceSettings,
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return SpaceSettingsScreen(spaceId: spaceId);
        },
      ),
      GoRoute(
        path: AppRoutes.joinSpace,
        builder: (context, state) {
          final token = state.pathParameters['token']!;
          return JoinSpaceScreen(token: token);
        },
      ),
    ],
  );
});
