import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';

void main() {
  group('routerProvider', () {
    test('builds a GoRouter starting at sign-in', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      expect(router.routeInformationProvider.value.uri.path, '/signin');
    });

    test('registers every route defined in AppRoutes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      final paths = router.configuration.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toSet();

      expect(
        paths,
        {
          AppRoutes.signIn,
          AppRoutes.home,
          AppRoutes.settings,
          AppRoutes.createSpace,
          AppRoutes.taskList,
          AppRoutes.spaceSettings,
          AppRoutes.joinSpace,
        },
      );
    });
  });
}
