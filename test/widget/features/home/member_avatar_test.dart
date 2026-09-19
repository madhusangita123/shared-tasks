import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/home/presentation/widgets/member_avatar.dart';

Future<void> _pump(WidgetTester t, Widget w) => t.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: w)),
  ),
);

BoxDecoration _deco(WidgetTester t) =>
    t
            .widget<Container>(
              find.descendant(
                of: find.byType(MemberAvatarCircle),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  testWidgets('shows uppercase initial', (t) async {
    await _pump(
      t,
      const MemberAvatarCircle(
        member: MemberAvatar(uid: 'u1', displayName: 'ada'),
      ),
    );
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('shows ? for empty name', (t) async {
    await _pump(
      t,
      const MemberAvatarCircle(
        member: MemberAvatar(uid: 'u1', displayName: ''),
      ),
    );
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('background from avatarSet, ring uses background colour', (
    t,
  ) async {
    await _pump(
      t,
      const MemberAvatarCircle(
        member: MemberAvatar(uid: 'u1', displayName: 'Ada'),
      ),
    );
    final d = _deco(t);
    expect(d.color, AppColors.avatarSet('u1'));
    final bg = AppTheme.light.extension<AppColors>()!.background;
    expect((d.border! as Border).top.color, bg);
  });

  testWidgets('default and custom size', (t) async {
    const m = MemberAvatar(uid: 'u1', displayName: 'Ada');
    await _pump(t, const MemberAvatarCircle(member: m));
    expect(t.getSize(find.byType(MemberAvatarCircle)), const Size(22, 22));
    await _pump(t, const MemberAvatarCircle(member: m, size: 40));
    expect(t.getSize(find.byType(MemberAvatarCircle)), const Size(40, 40));
  });
}
