import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';

/// App-wide [GoRouter] configuration.
///
/// Route builders are placeholders until each feature screen lands (see
/// CLAUDE.md — Feature build order). Auth-based redirect logic is wired up
/// once the `auth` feature provides `authStateProvider`.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.signIn,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Sign in'),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const _PlaceholderScreen(title: 'Home'),
      ),
      GoRoute(
        path: AppRoutes.createSpace,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Create space'),
      ),
      GoRoute(
        path: AppRoutes.taskList,
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return _PlaceholderScreen(title: 'Tasks — $spaceId');
        },
      ),
      GoRoute(
        path: AppRoutes.spaceSettings,
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return _PlaceholderScreen(title: 'Space settings — $spaceId');
        },
      ),
      GoRoute(
        path: AppRoutes.joinSpace,
        builder: (context, state) {
          final token = state.pathParameters['token']!;
          return _PlaceholderScreen(title: 'Join space — $token');
        },
      ),
    ],
  );
});

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title screen coming soon')),
    );
  }
}
