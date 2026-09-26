// Widget tests for MemberRow (issue #58) — the avatar + name + owner-label
// row rendered in SpaceSettingsScreen's Members section.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/home/presentation/widgets/member_avatar.dart';
import 'package:shared_tasks/features/spaces/presentation/widgets/member_row.dart';

const _member = MemberAvatar(uid: 'uid-1', displayName: 'Ada');

// AppTheme.light is mandatory: MemberRow reads AppColors.of(context), which
// null-asserts its ThemeExtension when the theme doesn't carry it.
Future<void> _pump(
  WidgetTester tester, {
  MemberAvatar member = _member,
  required bool isOwner,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MemberRow(member: member, isOwner: isOwner),
      ),
    ),
  );
}

void main() {
  group('MemberRow', () {
    testWidgets('renders the member display name', (tester) async {
      await _pump(tester, isOwner: false);

      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets('renders a MemberAvatarCircle for the member', (tester) async {
      await _pump(tester, isOwner: false);

      final avatar = tester.widget<MemberAvatarCircle>(
        find.byType(MemberAvatarCircle),
      );
      expect(avatar.member, _member);
    });

    testWidgets('the avatar is 36x36', (tester) async {
      await _pump(tester, isOwner: false);

      final avatar = tester.widget<MemberAvatarCircle>(
        find.byType(MemberAvatarCircle),
      );
      expect(avatar.size, 36);
      expect(
        tester.getSize(find.byType(MemberAvatarCircle)),
        const Size(36, 36),
      );
    });

    testWidgets('shows the "owner" label when isOwner is true', (tester) async {
      await _pump(tester, isOwner: true);

      expect(find.text('owner'), findsOneWidget);
    });

    testWidgets('does NOT show the "owner" label when isOwner is false', (
      tester,
    ) async {
      await _pump(tester, isOwner: false);

      expect(find.text('owner'), findsNothing);
    });

    testWidgets('shows the signed-in user by their own name, never "Me"', (
      tester,
    ) async {
      await _pump(
        tester,
        member: const MemberAvatar(uid: 'uid-9', displayName: 'Bea'),
        isOwner: false,
      );

      expect(find.text('Bea'), findsOneWidget);
      expect(find.text('Me'), findsNothing);
    });
  });
}
