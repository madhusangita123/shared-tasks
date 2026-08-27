import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/widgets/app_text_field.dart';

void main() {
  group('AppTextField', () {
    testWidgets('shows label and reports changes', (tester) async {
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: AppTextField(
              label: 'Title',
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Buy milk');
      expect(changed, 'Buy milk');
    });

    testWidgets('shows errorText when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: AppTextField(label: 'Title', errorText: 'Required'),
          ),
        ),
      );

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('pre-fills text from the given controller', (tester) async {
      final controller = TextEditingController(text: 'Buy milk');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: AppTextField(label: 'Title', controller: controller),
          ),
        ),
      );

      expect(find.text('Buy milk'), findsOneWidget);
    });

    testWidgets('passes maxLines and maxLength through to the TextField', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: AppTextField(label: 'Notes', maxLines: 3, maxLength: 500),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 3);
      expect(field.maxLength, 500);
    });
  });
}
