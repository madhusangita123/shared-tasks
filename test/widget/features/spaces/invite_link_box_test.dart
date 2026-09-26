// Widget tests for InviteLinkBox (issue #58) — the read-only, selectable
// display box for a space's invite link.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/spaces/presentation/widgets/invite_link_box.dart';

const _link = 'https://shared-tasks-dev.web.app/join/tok-abc';

// AppTheme.light is mandatory: InviteLinkBox reads AppColors.of(context).
Future<void> _pump(
  WidgetTester tester, {
  String link = _link,
  double width = 400,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: InviteLinkBox(link: link),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('InviteLinkBox', () {
    testWidgets('renders the given link text', (tester) async {
      await _pump(tester);

      expect(find.text(_link), findsOneWidget);
    });

    testWidgets('uses SelectableText so the link can be copied by hand', (
      tester,
    ) async {
      await _pump(tester);

      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectable.data, _link);
    });

    testWidgets('a long link wraps instead of overflowing at a narrow width', (
      tester,
    ) async {
      await _pump(
        tester,
        link:
            'https://shared-tasks-dev.web.app/join/'
            'a-very-long-invite-token-that-would-never-fit-on-one-line-at-all',
        width: 120,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
