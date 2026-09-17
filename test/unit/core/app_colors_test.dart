import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('light success and danger colors are distinct', () {
      expect(AppColors.light.success, isNot(AppColors.light.danger));
    });

    test('dark success and danger colors are distinct', () {
      expect(AppColors.dark.success, isNot(AppColors.dark.danger));
    });

    test('light brand colors are distinct', () {
      expect(
        {
          AppColors.light.primary,
          AppColors.light.primaryLight,
          AppColors.light.accent,
        },
        hasLength(3),
      );
    });

    test('light background and surface are distinct', () {
      expect(AppColors.light.background, isNot(AppColors.light.surface));
    });

    test('dark background and surface are distinct', () {
      expect(AppColors.dark.background, isNot(AppColors.dark.surface));
    });

    test('light and dark background differ', () {
      expect(AppColors.light.background, isNot(AppColors.dark.background));
    });

    test('avatarSet is deterministic for the same uid', () {
      expect(AppColors.avatarSet('uid-1'), AppColors.avatarSet('uid-1'));
    });

    test('avatarSet can differ across uids', () {
      final colors = {
        for (var i = 0; i < 20; i++) AppColors.avatarSet('uid-$i'),
      };
      expect(colors.length, greaterThan(1));
    });

    test('copyWith overrides only the given fields', () {
      final overridden = AppColors.light.copyWith(primary: AppColors.dark.primary);
      expect(overridden.primary, AppColors.dark.primary);
      expect(overridden.background, AppColors.light.background);
    });

    test('lerp at t=0 returns the start colors', () {
      final result = AppColors.light.lerp(AppColors.dark, 0);
      expect(result.background, AppColors.light.background);
    });

    test('lerp at t=1 returns the end colors', () {
      final result = AppColors.light.lerp(AppColors.dark, 1);
      expect(result.background, AppColors.dark.background);
    });

    test('avatarSet always picks from the fixed 8-color palette', () {
      final expectedPalette = <Color>[
        const Color(0xFFEF4444),
        const Color(0xFFF59E0B),
        const Color(0xFF1D9E75),
        const Color(0xFF0EA5E9),
        const Color(0xFF6366F1),
        const Color(0xFFA855F7),
        const Color(0xFFEC4899),
        const Color(0xFF14B8A6),
      ];
      for (var i = 0; i < 50; i++) {
        expect(expectedPalette, contains(AppColors.avatarSet('user-$i')));
      }
    });

    test('avatarSet is deterministic across repeated calls', () {
      final first = AppColors.avatarSet('stable-uid');
      for (var i = 0; i < 5; i++) {
        expect(AppColors.avatarSet('stable-uid'), first);
      }
    });

    testWidgets('of(context) resolves to AppColors.light under a light theme', (
      tester,
    ) async {
      AppColors? resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              resolved = AppColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, AppColors.light);
    });

    testWidgets('of(context) resolves to AppColors.dark under a dark theme', (
      tester,
    ) async {
      AppColors? resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              resolved = AppColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, AppColors.dark);
    });
  });
}
