import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses Material 3', () {
      expect(AppTheme.light.useMaterial3, isTrue);
    });

    test('light theme colorScheme uses AppColors primary and error', () {
      final colorScheme = AppTheme.light.colorScheme;
      expect(colorScheme.primary, AppColors.primary);
      expect(colorScheme.error, AppColors.error);
    });

    test('light theme scaffold background matches AppColors', () {
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.background);
    });

    test('light theme app bar is flat and left-aligned', () {
      final appBarTheme = AppTheme.light.appBarTheme;
      expect(appBarTheme.elevation, 0);
      expect(appBarTheme.centerTitle, isFalse);
      expect(appBarTheme.backgroundColor, AppColors.background);
    });

    test('light theme elevated button uses white foreground on primary', () {
      final style = AppTheme.light.elevatedButtonTheme.style;
      expect(
        style?.foregroundColor?.resolve(<WidgetState>{}),
        equals(Colors.white),
      );
      expect(style?.backgroundColor?.resolve(<WidgetState>{}), AppColors.primary);
    });
  });
}
