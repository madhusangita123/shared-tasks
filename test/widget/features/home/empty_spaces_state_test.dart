import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/home/presentation/widgets/empty_spaces_state.dart';

void main() {
  testWidgets('shows copy and navigates on button tap', (t) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: EmptySpacesState()),
        ),
        GoRoute(
          path: AppRoutes.createSpace,
          builder: (_, __) => const Scaffold(body: Text('CREATE DEST')),
        ),
      ],
    );
    await t.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );

    expect(find.text('No spaces yet'), findsOneWidget);
    expect(find.text('Create your first space to get started'), findsOneWidget);
    expect(find.text('Create space'), findsOneWidget);

    await t.tap(find.text('Create space'));
    await t.pumpAndSettle();
    expect(find.text('CREATE DEST'), findsOneWidget);
  });
}
