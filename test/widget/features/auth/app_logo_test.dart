// Widget tests for AppLogo (issue #59) — 64x64 rounded square containing
// three horizontal white line bars simulating a checklist mark.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/auth/presentation/widgets/app_logo.dart';

void main() {
  group('AppLogo', () {
    testWidgets('renders at 64x64 with rounded-square decoration',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Center(child: AppLogo()),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(AppLogo),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      final size = tester.getSize(find.byType(AppLogo));
      expect(size.width, 64);
      expect(size.height, 64);

      final outerContainer = tester.widget<Container>(
        containerFinder.first,
      );
      final decoration = outerContainer.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(18));
    });

    testWidgets('renders three checklist line bars', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Center(child: AppLogo()),
        ),
      );

      // Each "line" is a Container wrapped in a FractionallySizedBox, plus
      // the outer square Container itself — so 3 lines + 1 outer = 4.
      expect(
        find.descendant(
          of: find.byType(AppLogo),
          matching: find.byType(Container),
        ),
        findsNWidgets(4),
      );
      expect(
        find.descendant(
          of: find.byType(AppLogo),
          matching: find.byType(FractionallySizedBox),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('middle line is 65% width, first and third are full width',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Center(child: AppLogo()),
        ),
      );

      final fractionalBoxes = tester
          .widgetList<FractionallySizedBox>(
            find.descendant(
              of: find.byType(AppLogo),
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .toList();

      expect(fractionalBoxes[0].widthFactor, 1);
      expect(fractionalBoxes[1].widthFactor, 0.65);
      expect(fractionalBoxes[2].widthFactor, 1);
    });
  });
}
