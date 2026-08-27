import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/router/app_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';

void main() {
  group('routerProvider navigation', () {
    testWidgets('sign-in route renders its placeholder screen', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets('home route renders its placeholder screen', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('create space route renders its placeholder screen', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      router.go(AppRoutes.createSpace);
      await tester.pumpAndSettle();

      expect(find.text('Create space'), findsWidgets);
    });

    testWidgets('task list route extracts spaceId from the path', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      router.go(AppRoutes.taskListPath('space42'));
      await tester.pumpAndSettle();

      expect(find.text('Tasks — space42'), findsWidgets);
    });

    testWidgets('space settings route extracts spaceId from the path', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      router.go(AppRoutes.spaceSettingsPath('space42'));
      await tester.pumpAndSettle();

      expect(find.text('Space settings — space42'), findsWidgets);
    });

    testWidgets('join space route extracts the token from the path', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      router.go(AppRoutes.joinSpacePath('tok-999'));
      await tester.pumpAndSettle();

      expect(find.text('Join space — tok-999'), findsWidgets);
    });
  });
}
