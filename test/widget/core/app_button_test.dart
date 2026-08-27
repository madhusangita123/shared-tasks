import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';

void main() {
  group('AppButton', () {
    testWidgets('shows label and invokes onPressed when tapped', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppButton(label: 'Continue', onPressed: () => tapped = true),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      expect(tapped, isTrue);
    });

    testWidgets('shows a spinner and disables tap when isLoading', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppButton(
            label: 'Continue',
            isLoading: true,
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      expect(tapped, isFalse);
    });

    testWidgets('shows the icon before the label when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppButton(
            label: 'Continue',
            icon: Icons.check,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppButton(label: 'Continue', onPressed: null),
        ),
      );

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.enabled, isFalse);
    });
  });
}
