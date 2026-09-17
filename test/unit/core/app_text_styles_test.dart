import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';

void main() {
  group('AppTextStyles', () {
    test('instance provides non-null styles for every named style', () {
      const styles = AppTextStyles.instance;
      expect(styles.headingLarge, isA<TextStyle>());
      expect(styles.headingMedium, isA<TextStyle>());
      expect(styles.bodyLarge, isA<TextStyle>());
      expect(styles.bodyMedium, isA<TextStyle>());
      expect(styles.bodySmall, isA<TextStyle>());
      expect(styles.caption, isA<TextStyle>());
      expect(styles.label, isA<TextStyle>());
    });

    testWidgets('of(context) resolves without throwing and returns non-null styles', (
      tester,
    ) async {
      AppTextStyles? resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              resolved = AppTextStyles.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(resolved!.headingLarge, isA<TextStyle>());
      expect(resolved!.headingMedium, isA<TextStyle>());
      expect(resolved!.bodyLarge, isA<TextStyle>());
      expect(resolved!.bodyMedium, isA<TextStyle>());
      expect(resolved!.bodySmall, isA<TextStyle>());
      expect(resolved!.caption, isA<TextStyle>());
      expect(resolved!.label, isA<TextStyle>());
    });

    test('copyWith overrides only the given field', () {
      const original = AppTextStyles.instance;
      final overridden = original.copyWith(
        headingLarge: const TextStyle(fontSize: 99),
      );
      expect(overridden.headingLarge.fontSize, 99);
      expect(overridden.bodyLarge, original.bodyLarge);
    });

    test('lerp returns the same instance unchanged', () {
      const original = AppTextStyles.instance;
      expect(original.lerp(original, 0.5), same(original));
    });
  });
}
