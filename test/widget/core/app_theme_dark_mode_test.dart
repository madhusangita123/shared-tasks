import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';

void main() {
  testWidgets(
    'MaterialApp with themeMode.dark resolves AppColors.dark end-to-end',
    (tester) async {
      AppColors? resolvedColors;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              resolvedColors = Theme.of(context).extension<AppColors>();
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedColors, equals(AppColors.dark));
    },
  );

  testWidgets(
    'MaterialApp with themeMode.light resolves AppColors.light end-to-end',
    (tester) async {
      AppColors? resolvedColors;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              resolvedColors = Theme.of(context).extension<AppColors>();
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedColors, equals(AppColors.light));
    },
  );
}
