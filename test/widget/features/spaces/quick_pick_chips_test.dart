import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/spaces/presentation/widgets/quick_pick_chips.dart';

const _labels = ['House', 'Kids', 'Shopping', 'Personal', 'Work', 'Health'];

Future<List<String>> _pump(WidgetTester tester) async {
  final selected = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: QuickPickChips(onSelected: selected.add)),
    ),
  );
  return selected;
}

void main() {
  group('QuickPickChips', () {
    testWidgets('renders the Quick pick label', (tester) async {
      await _pump(tester);
      expect(find.text('QUICK PICK'), findsOneWidget);
    });

    testWidgets('renders all six chip labels', (tester) async {
      await _pump(tester);
      for (final l in _labels) {
        expect(find.text(l), findsOneWidget);
      }
    });

    for (final l in _labels) {
      testWidgets('tapping $l calls onSelected with "$l"', (tester) async {
        final selected = await _pump(tester);
        await tester.tap(find.text(l));
        await tester.pump();
        expect(selected, [l]);
      });
    }
  });
}
