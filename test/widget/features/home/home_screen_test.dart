// Widget tests for HomeScreen (S-02) via userSpacesProvider override.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';
import 'package:shared_tasks/features/home/presentation/home_screen.dart';
import 'package:shared_tasks/features/home/presentation/providers/home_provider.dart';
import 'package:shared_tasks/features/home/presentation/widgets/empty_spaces_state.dart';
import 'package:shared_tasks/features/home/presentation/widgets/space_card.dart';

HomeSpace _space(
  String id,
  String name,
  int open, {
  List<MemberAvatar> avatars = const [],
}) => HomeSpace(
  id: id,
  name: name,
  memberUids: const ['uid-1'],
  openTaskCount: open,
  updatedAt: DateTime(2026),
  memberAvatars: avatars,
);

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: AppRoutes.settings,
      builder: (_, __) => const Scaffold(body: Text('SETTINGS DEST')),
    ),
    GoRoute(
      path: AppRoutes.createSpace,
      builder: (_, __) => const Scaffold(body: Text('CREATE DEST')),
    ),
    GoRoute(
      path: AppRoutes.taskList,
      builder: (_, __) => const Scaffold(body: Text('TASKS DEST')),
    ),
  ],
  initialLocation: AppRoutes.home,
);

Future<void> _pump(
  WidgetTester t,
  Stream<List<HomeSpace>> stream, {
  bool dark = false,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [userSpacesProvider.overrideWith((ref) => stream)],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: _router(),
      ),
    ),
  );
  await t.pump();
}

void main() {
  testWidgets('loading state', (t) async {
    await _pump(t, const Stream.empty());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SpaceCard), findsNothing);
  });

  testWidgets('error state', (t) async {
    await _pump(t, Stream.error(Exception('boom')));
    expect(
      find.text('Something went wrong loading your spaces.'),
      findsOneWidget,
    );
  });

  testWidgets('empty state', (t) async {
    await _pump(t, Stream.value(const []));
    expect(find.byType(EmptySpacesState), findsOneWidget);
    expect(find.text('My spaces'), findsOneWidget);
    expect(find.text('0 spaces · 0 open tasks'), findsOneWidget);
  });

  testWidgets('populated: cards, header, summed counts', (t) async {
    await _pump(
      t,
      Stream.value([_space('a', 'Alpha', 3), _space('b', 'Beta', 4)]),
    );
    expect(find.byType(SpaceCard), findsNWidgets(2));
    expect(find.text('My spaces'), findsOneWidget);
    expect(find.text('2 spaces · 7 open tasks'), findsOneWidget);
  });

  testWidgets('singular subtitle', (t) async {
    await _pump(t, Stream.value([_space('a', 'Alpha', 1)]));
    expect(find.text('1 space · 1 open task'), findsOneWidget);
  });

  testWidgets('FAB navigates to create space', (t) async {
    await _pump(t, Stream.value(const []));
    await t.tap(find.byIcon(Icons.add));
    await t.pumpAndSettle();
    expect(find.text('CREATE DEST'), findsOneWidget);
  });

  testWidgets('FAB has an accessible Create space tooltip', (t) async {
    await _pump(t, Stream.value(const []));
    expect(find.byTooltip('Create space'), findsOneWidget);
  });

  testWidgets('settings gear navigates', (t) async {
    await _pump(t, Stream.value(const []));
    await t.tap(find.byIcon(Icons.settings));
    await t.pumpAndSettle();
    expect(find.text('SETTINGS DEST'), findsOneWidget);
  });

  testWidgets('card tap navigates to task list', (t) async {
    await _pump(t, Stream.value([_space('a', 'Alpha', 3)]));
    await t.tap(find.text('Alpha'));
    await t.pumpAndSettle();
    expect(find.text('TASKS DEST'), findsOneWidget);
  });

  testWidgets('dark mode renders without exceptions', (t) async {
    await _pump(
      t,
      Stream.value([
        _space(
          'a',
          'Alpha',
          3,
          avatars: const [MemberAvatar(uid: 'u', displayName: 'Ada')],
        ),
      ]),
      dark: true,
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
