import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/home/presentation/widgets/avatar_stack.dart';
import 'package:shared_tasks/features/home/presentation/widgets/member_avatar.dart';

List<MemberAvatar> _m(int n) => [
  for (var i = 0; i < n; i++) MemberAvatar(uid: 'u$i', displayName: 'Name$i'),
];

Future<void> _pump(WidgetTester t, int n) => t.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(child: AvatarStack(members: _m(n))),
    ),
  ),
);

void main() {
  for (final n in [1, 2, 3]) {
    testWidgets('$n members render $n circles, no overflow', (t) async {
      await _pump(t, n);
      expect(find.byType(MemberAvatarCircle), findsNWidgets(n));
      expect(find.textContaining('+'), findsNothing);
    });
  }

  testWidgets('5 members render 3 avatars and +2', (t) async {
    await _pump(t, 5);
    expect(find.byType(MemberAvatarCircle), findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('4 members show +1', (t) async {
    await _pump(t, 4);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('avatars overlap by 6px', (t) async {
    await _pump(t, 2);
    final a = t.getTopLeft(find.byType(MemberAvatarCircle).at(0)).dx;
    final b = t.getTopLeft(find.byType(MemberAvatarCircle).at(1)).dx;
    expect(b - a, 22 - 6);
  });
}
