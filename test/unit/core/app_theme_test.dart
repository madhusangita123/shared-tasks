import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';

void main() {
  group('AppTheme light', () {
    test('uses Material 3', () {
      expect(AppTheme.light.useMaterial3, isTrue);
    });

    test('colorScheme uses AppColors primary and error', () {
      final colorScheme = AppTheme.light.colorScheme;
      expect(colorScheme.primary, AppColors.light.primary);
      expect(colorScheme.error, AppColors.light.danger);
    });

    test('scaffold background matches AppColors', () {
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.light.background);
    });

    test('app bar is flat and left-aligned', () {
      final appBarTheme = AppTheme.light.appBarTheme;
      expect(appBarTheme.elevation, 0);
      expect(appBarTheme.centerTitle, isFalse);
      expect(appBarTheme.backgroundColor, AppColors.light.background);
    });

    test('elevated button uses white foreground on primary', () {
      final style = AppTheme.light.elevatedButtonTheme.style;
      expect(
        style?.foregroundColor?.resolve(<WidgetState>{}),
        equals(Colors.white),
      );
      expect(
        style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.light.primary,
      );
    });

    test('registers AppColors.light and AppTextStyles extensions', () {
      expect(AppTheme.light.extension<AppColors>(), AppColors.light);
      expect(AppTheme.light.extension<AppTextStyles>(), AppTextStyles.instance);
    });
  });

  group('AppTheme dark', () {
    test('uses Material 3', () {
      expect(AppTheme.dark.useMaterial3, isTrue);
    });

    test('colorScheme uses AppColors primary and error', () {
      final colorScheme = AppTheme.dark.colorScheme;
      expect(colorScheme.primary, AppColors.dark.primary);
      expect(colorScheme.error, AppColors.dark.danger);
    });

    test('scaffold background matches AppColors', () {
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.dark.background);
    });

    test('registers AppColors.dark and AppTextStyles extensions', () {
      expect(AppTheme.dark.extension<AppColors>(), AppColors.dark);
      expect(AppTheme.dark.extension<AppTextStyles>(), AppTextStyles.instance);
    });
  });
}
