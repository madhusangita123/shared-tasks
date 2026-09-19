import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';
import 'package:shared_tasks/features/home/presentation/widgets/avatar_stack.dart';
import 'package:shared_tasks/features/home/presentation/widgets/space_card.dart';

HomeSpace _s({int open = 2, List<MemberAvatar> avatars = const []}) =>
    HomeSpace(
      id: 'sp1',
      name: 'Household',
      memberUids: const ['a'],
      openTaskCount: open,
      updatedAt: DateTime(2026),
      memberAvatars: avatars,
    );

Future<void> _pump(WidgetTester t, HomeSpace s) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(body: SpaceCard(space: s)),
      ),
      GoRoute(
        path: AppRoutes.taskList,
        builder: (_, __) => const Scaffold(body: Text('TASKS DEST')),
      ),
    ],
  );
  return t.pumpWidget(
    MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  testWidgets('shows name and plural count', (t) async {
    await _pump(t, _s(open: 3));
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('3 open tasks'), findsOneWidget);
  });

  testWidgets('singular and zero', (t) async {
    await _pump(t, _s(open: 1));
    expect(find.text('1 open task'), findsOneWidget);
    await _pump(t, _s(open: 0));
    await t.pumpAndSettle();
    expect(find.text('No open tasks'), findsOneWidget);
  });

  testWidgets('avatar stack only with members', (t) async {
    await _pump(t, _s());
    expect(find.byType(AvatarStack), findsNothing);
    await _pump(
      t,
      _s(
        avatars: const [MemberAvatar(uid: 'a', displayName: 'Ada')],
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(AvatarStack), findsOneWidget);
  });

  testWidgets('tap navigates to task list', (t) async {
    await _pump(t, _s());
    await t.tap(find.text('Household'));
    await t.pumpAndSettle();
    expect(find.text('TASKS DEST'), findsOneWidget);
  });

  testWidgets('long name is capped at 2 lines with ellipsis', (t) async {
    final long = HomeSpace(
      id: 'sp1',
      name: List.filled(40, 'Household').join(' '),
      memberUids: const ['a'],
      openTaskCount: 1,
      updatedAt: DateTime(2026),
      memberAvatars: const [],
    );
    await _pump(t, long);
    final text = t.widget<Text>(find.text(long.name));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(t.takeException(), isNull);
  });
}
